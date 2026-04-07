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

    // Fix 2: Static cached ISO8601 formatters
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ string: String) -> Date? {
        UsageDataService.iso8601Formatter.date(from: string) ??
        UsageDataService.iso8601FormatterNoFraction.date(from: string)
    }

    init() {
        loadData()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.loadData() }
        }
    }

    // Fix 1: Move file I/O off main thread using Task.detached
    func loadData() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let files = await Task.detached(priority: .userInitiated) { [resolver] in
                resolver.resolveJSONLFiles()
            }.value
            let entries = await Task.detached(priority: .userInitiated) { [parser] in
                parser.parse(files: files)
            }.value
            // Back on MainActor
            self.allEntries = entries
            var newStats: [TimeDimension: AggregatedStats] = [:]
            for dim in TimeDimension.allCases {
                newStats[dim] = self.aggregate(entries: entries, for: dim)
            }
            self.stats = newStats
            self.lastRefreshed = Date()
            self.isLoading = false
        }
    }

    func refreshIfNeeded() {
        guard let last = lastRefreshed else { loadData(); return }
        if Date().timeIntervalSince(last) > 300 { loadData() }
    }

    func aggregate(entries: [UsageEntry], for dimension: TimeDimension) -> AggregatedStats {
        let cal = Calendar.current
        let now = Date()

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
        // Fix 5: Accumulate cache savings using per-entry model pricing
        var cacheSavings = 0.0

        for (e, d) in currentEntries {
            let cost = calculator.cost(for: e)
            totalCost += cost
            let usage = e.message?.usage
            let i = usage?.inputTokens ?? 0
            let o = usage?.outputTokens ?? 0
            let cr = usage?.cacheReadInputTokens ?? 0
            let cc = usage?.cacheCreationInputTokens ?? 0
            input += i; output += o; cacheRead += cr; cacheCreate += cc
            // Fix 5: savings = cacheRead * (inputPrice - cacheReadPrice) per entry's model
            cacheSavings += calculator.cacheSavings(for: e)
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

        // Fix 3: Chart bars with pre-parsed dates
        let bars = makeChartBars(entries: entries, dimension: dimension, calendar: cal)

        return AggregatedStats(
            totalCostUSD: totalCost, totalTokens: totalTokens,
            inputTokens: input, outputTokens: output,
            cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate,
            cacheHitRate: cacheHitRate, costDelta: costDelta,
            tokenDeltaPercent: tokenDeltaPercent,
            sessionCount: sessions.count, projectCount: projects.count,
            activeDuration: activeDuration,
            modelBreakdowns: breakdowns, chartBars: bars,
            dimensionLabel: dimension.periodLabel,
            cacheSavingsUSD: cacheSavings
        )
    }

    // Fix 3 & 8: Extract periodBounds helper; pre-parse dates once; no force-unwraps
    private func periodBounds(
        offsetFromNow: Int,
        dimension: TimeDimension,
        calendar: Calendar,
        now: Date
    ) -> (start: Date, end: Date, label: String, isCurrent: Bool) {
        let unit: Calendar.Component
        switch dimension {
        case .day:   unit = .day
        case .week:  unit = .weekOfYear
        case .month: unit = .month
        case .year:  unit = .year
        }

        guard let periodDate = calendar.date(byAdding: unit, value: offsetFromNow, to: now) else {
            return (now, now, "", false)
        }

        let start: Date
        let end: Date
        switch dimension {
        case .day:
            start = calendar.startOfDay(for: periodDate)
            end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        case .week:
            let weekComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: periodDate)
            start = calendar.date(from: weekComps) ?? periodDate
            end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        case .month:
            let monthComps = calendar.dateComponents([.year, .month], from: periodDate)
            start = calendar.date(from: monthComps) ?? periodDate
            end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        case .year:
            let yearComps = calendar.dateComponents([.year], from: periodDate)
            start = calendar.date(from: yearComps) ?? periodDate
            end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        }

        let label: String
        switch dimension {
        case .day:   label = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: periodDate) - 1]
        case .week:  label = "W\(calendar.component(.weekOfYear, from: periodDate))"
        case .month: label = calendar.shortMonthSymbols[calendar.component(.month, from: periodDate) - 1]
        case .year:  label = "\(calendar.component(.year, from: periodDate))"
        }

        let isCurrent: Bool
        switch dimension {
        case .day:   isCurrent = calendar.isDateInToday(periodDate)
        case .week:  isCurrent = calendar.isDate(periodDate, equalTo: now, toGranularity: .weekOfYear)
        case .month: isCurrent = calendar.isDate(periodDate, equalTo: now, toGranularity: .month)
        case .year:  isCurrent = calendar.isDate(periodDate, equalTo: now, toGranularity: .year)
        }

        return (start, end, label, isCurrent)
    }

    private func makeChartBars(entries: [UsageEntry], dimension: TimeDimension, calendar: Calendar) -> [PeriodBar] {
        // Fix 3: Pre-parse all dates once — O(n) instead of O(n * barCount)
        let dated: [(UsageEntry, Date)] = entries.compactMap { entry in
            guard let date = parseDate(entry.timestamp) else { return nil }
            return (entry, date)
        }

        let now = Date()
        var bars: [PeriodBar] = []

        for i in stride(from: dimension.barCount - 1, through: 0, by: -1) {
            let (periodStart, periodEnd, label, isCurrent) = periodBounds(
                offsetFromNow: -i, dimension: dimension, calendar: calendar, now: now
            )
            let periodEntries = dated.filter { $0.1 >= periodStart && $0.1 < periodEnd }
            let inputTokens  = periodEntries.reduce(0) { $0 + ($1.0.message?.usage?.inputTokens ?? 0) }
            let outputTokens = periodEntries.reduce(0) { $0 + ($1.0.message?.usage?.outputTokens ?? 0) }
            bars.append(PeriodBar(label: label, inputTokens: inputTokens, outputTokens: outputTokens, isCurrentPeriod: isCurrent))
        }
        return bars
    }
}
