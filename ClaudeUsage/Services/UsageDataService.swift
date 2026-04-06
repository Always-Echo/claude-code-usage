import Foundation
import Combine

@MainActor
class UsageDataService: ObservableObject {
    @Published var stats: [TimeDimension: AggregatedStats] = [:]
    @Published var lastRefreshed: Date?
    @Published var isLoading: Bool = false

    private(set) var allEntries: [UsageEntry] = []
    private var timer: Timer?
    private let resolver = ClaudePathResolver()
    private let parser = JSONLParser()
    private let calculator = CostCalculator()

    init() {
        loadData()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.loadData() }
        }
    }

    func loadData() {
        isLoading = true
        let files = resolver.resolveJSONLFiles()
        allEntries = parser.parse(files: files)
        var newStats: [TimeDimension: AggregatedStats] = [:]
        for dim in TimeDimension.allCases {
            newStats[dim] = aggregate(entries: allEntries, for: dim)
        }
        stats = newStats
        lastRefreshed = Date()
        isLoading = false
    }

    func refreshIfNeeded() {
        guard let last = lastRefreshed else { loadData(); return }
        if Date().timeIntervalSince(last) > 300 { loadData() }
    }

    func aggregate(entries: [UsageEntry], for dimension: TimeDimension) -> AggregatedStats {
        let cal = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()

        func parseDate(_ s: String) -> Date? {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: s) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: s)
        }

        func isInCurrentPeriod(_ date: Date) -> Bool {
            switch dimension {
            case .day:   return cal.isDateInToday(date)
            case .week:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return cal.isDate(date, equalTo: now, toGranularity: .month)
            case .year:  return cal.isDate(date, equalTo: now, toGranularity: .year)
            }
        }

        func isInPreviousPeriod(_ date: Date) -> Bool {
            switch dimension {
            case .day:
                return cal.isDateInYesterday(date)
            case .week:
                guard let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear)
            case .month:
                guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
            case .year:
                guard let lastYear = cal.date(byAdding: .year, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastYear, toGranularity: .year)
            }
        }

        let currentEntries: [(UsageEntry, Date)] = entries.compactMap { e in
            guard let d = parseDate(e.timestamp), isInCurrentPeriod(d) else { return nil }
            return (e, d)
        }

        let prevEntries: [(UsageEntry, Date)] = entries.compactMap { e in
            guard let d = parseDate(e.timestamp), isInPreviousPeriod(d) else { return nil }
            return (e, d)
        }

        // Compute totals
        var totalCost = 0.0, input = 0, output = 0, cacheRead = 0, cacheCreate = 0
        var sessions = Set<String>(), projects = Set<String>()
        var modelCosts: [String: (tokens: Int, cost: Double)] = [:]
        var dates: [Date] = []

        for (e, d) in currentEntries {
            let cost = calculator.cost(for: e)
            totalCost += cost
            let usage = e.message?.usage
            let i = usage?.inputTokens ?? 0
            let o = usage?.outputTokens ?? 0
            let cr = usage?.cacheReadInputTokens ?? 0
            let cc = usage?.cacheCreationInputTokens ?? 0
            input += i; output += o; cacheRead += cr; cacheCreate += cc
            if let s = e.sessionId { sessions.insert(s) }
            if let p = e.cwd { projects.insert(p) }
            let model = e.message?.model ?? "unknown"
            let existing = modelCosts[model] ?? (0, 0)
            modelCosts[model] = (existing.tokens + i + o + cr + cc, existing.cost + cost)
            dates.append(d)
        }

        let totalTokens = input + output + cacheRead + cacheCreate
        let cacheHitRate = totalTokens > 0 ? Double(cacheRead) / Double(totalTokens) : 0

        // Previous period for delta
        var prevCost = 0.0, prevTokens = 0
        for (e, _) in prevEntries {
            prevCost += calculator.cost(for: e)
            let usage = e.message?.usage
            let pi = usage?.inputTokens ?? 0
            let po = usage?.outputTokens ?? 0
            let pr = usage?.cacheReadInputTokens ?? 0
            let pc = usage?.cacheCreationInputTokens ?? 0
            prevTokens += pi + po + pr + pc
        }
        let costDelta = totalCost - prevCost
        let tokenDeltaPercent = prevTokens > 0 ? Double(totalTokens - prevTokens) / Double(prevTokens) * 100 : 0

        let activeDuration: TimeInterval = dates.isEmpty ? 0 : (dates.max()!.timeIntervalSince(dates.min()!))

        // Model breakdowns sorted by cost desc
        let breakdowns = modelCosts.map { (name, v) in
            ModelBreakdown(modelName: name, totalTokens: v.tokens, costUSD: v.cost,
                          costRatio: totalCost > 0 ? v.cost / totalCost : 0)
        }.sorted { $0.costUSD > $1.costUSD }

        // Chart bars
        let bars = makeChartBars(entries: entries, dimension: dimension, now: now, parseFn: parseDate)

        return AggregatedStats(
            totalCostUSD: totalCost, totalTokens: totalTokens,
            inputTokens: input, outputTokens: output,
            cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate,
            cacheHitRate: cacheHitRate, costDelta: costDelta,
            tokenDeltaPercent: tokenDeltaPercent,
            sessionCount: sessions.count, projectCount: projects.count,
            activeDuration: activeDuration,
            modelBreakdowns: breakdowns, chartBars: bars,
            dimensionLabel: dimension.periodLabel
        )
    }

    private func makeChartBars(entries: [UsageEntry], dimension: TimeDimension, now: Date,
                                parseFn: (String) -> Date?) -> [PeriodBar] {
        let cal = Calendar.current
        var bars: [PeriodBar] = []

        for i in stride(from: dimension.barCount - 1, through: 0, by: -1) {
            let offset = -i
            let periodDate: Date
            switch dimension {
            case .day:   periodDate = cal.date(byAdding: .day, value: offset, to: now)!
            case .week:  periodDate = cal.date(byAdding: .weekOfYear, value: offset, to: now)!
            case .month: periodDate = cal.date(byAdding: .month, value: offset, to: now)!
            case .year:  periodDate = cal.date(byAdding: .year, value: offset, to: now)!
            }

            func inPeriod(_ d: Date) -> Bool {
                switch dimension {
                case .day:   return cal.isDate(d, inSameDayAs: periodDate)
                case .week:  return cal.isDate(d, equalTo: periodDate, toGranularity: .weekOfYear)
                case .month: return cal.isDate(d, equalTo: periodDate, toGranularity: .month)
                case .year:  return cal.isDate(d, equalTo: periodDate, toGranularity: .year)
                }
            }

            var inp = 0, out = 0
            for e in entries {
                guard let d = parseFn(e.timestamp), inPeriod(d) else { continue }
                inp += e.message?.usage?.inputTokens ?? 0
                out += e.message?.usage?.outputTokens ?? 0
            }

            let label: String
            switch dimension {
            case .day:   label = cal.shortWeekdaySymbols[cal.component(.weekday, from: periodDate) - 1]
            case .week:  label = "W\(cal.component(.weekOfYear, from: periodDate))"
            case .month: label = cal.shortMonthSymbols[cal.component(.month, from: periodDate) - 1]
            case .year:  label = "\(cal.component(.year, from: periodDate))"
            }

            let isCurrent: Bool
            switch dimension {
            case .day:   isCurrent = cal.isDateInToday(periodDate)
            case .week:  isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .weekOfYear)
            case .month: isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .month)
            case .year:  isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .year)
            }

            bars.append(PeriodBar(label: label, inputTokens: inp, outputTokens: out, isCurrentPeriod: isCurrent))
        }
        return bars
    }
}
