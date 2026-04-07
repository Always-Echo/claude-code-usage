import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var dataService: UsageDataService
    @State private var selectedDimension: TimeDimension = .day
    @State private var now: Date = Date()

    private var stats: AggregatedStats {
        dataService.stats[selectedDimension] ?? .empty
    }

    private var refreshLabel: String {
        guard let last = dataService.lastRefreshed else { return "never" }
        let mins = Int(now.timeIntervalSince(last) / 60)
        return mins < 1 ? "just now" : "\(mins)m ago"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.spacing8) {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.accent.opacity(0.6), radius: 3)
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(refreshLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.textFaint)
            }
            .padding(.horizontal, DS.spacing12)
            .padding(.vertical, DS.spacing8)

            Divider().background(Color.borderSubtle)

            DimensionTabBar(selectedDimension: $selectedDimension)
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                    now = Date()
                }

            Divider().background(Color.borderSubtle)

            if dataService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if dataService.allEntries.isEmpty {
                VStack(spacing: DS.spacing8) {
                    Text("未找到 Claude Code 数据")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                    Text("请确认已安装并使用过 Claude Code")
                        .font(.system(size: 11))
                        .foregroundColor(.textFaint)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        SummaryCardsRow(stats: stats)

                        Divider().background(Color.borderSubtle)

                        VStack(alignment: .leading, spacing: DS.spacing4) {
                            Text("近\(stats.chartBars.count)期用量")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.textFaint)
                                .padding(.horizontal, DS.spacing12)
                                .padding(.top, DS.spacing8)
                            BarChartView(bars: stats.chartBars)
                        }

                        Divider().background(Color.borderSubtle)

                        TokenBreakdownGrid(stats: stats)

                        Divider().background(Color.borderSubtle)

                        if !stats.modelBreakdowns.isEmpty {
                            ModelBreakdownList(models: stats.modelBreakdowns)
                            Divider().background(Color.borderSubtle)
                        }

                        SessionsInfoRow(stats: stats)
                    }
                }
            }

            Divider().background(Color.borderSubtle)

            FooterTotalRow(stats: stats, dimension: selectedDimension)
        }
        .frame(width: DS.panelWidth)
        .background(Color.background)
    }
}
