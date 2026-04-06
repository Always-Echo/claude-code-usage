import SwiftUI

struct BarChartView: View {
    let bars: [PeriodBar]
    private let chartHeight: CGFloat = 52
    private let minBarHeight: CGFloat = 2

    private var maxTotal: Int {
        bars.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing8) {
            // Legend
            HStack(spacing: DS.spacing12) {
                LegendDot(color: .accent, label: "Output")
                LegendDot(color: .accentDim, label: "Input")
                Spacer()
            }

            // Bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(bars) { bar in
                    BarColumn(bar: bar, maxTotal: maxTotal,
                              chartHeight: chartHeight, minBarHeight: minBarHeight)
                }
            }
            .frame(height: chartHeight + 16) // extra for labels
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }
}

struct BarColumn: View {
    let bar: PeriodBar
    let maxTotal: Int
    let chartHeight: CGFloat
    let minBarHeight: CGFloat

    private func height(for tokens: Int) -> CGFloat {
        guard maxTotal > 0 else { return minBarHeight }
        let h = CGFloat(tokens) / CGFloat(maxTotal) * chartHeight
        return max(h, tokens > 0 ? minBarHeight : 0)
    }

    var body: some View {
        VStack(spacing: 2) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(bar.isCurrentPeriod ? Color.accent : Color.accent.opacity(0.6))
                    .frame(height: height(for: bar.outputTokens))
                Rectangle()
                    .fill(bar.isCurrentPeriod ? Color.accentDim : Color.accentDim.opacity(0.6))
                    .frame(height: height(for: bar.inputTokens))
            }
            .frame(height: chartHeight)
            .shadow(color: bar.isCurrentPeriod ? Color.accent.opacity(0.4) : .clear, radius: 4)

            Text(bar.label)
                .font(.system(size: 8))
                .foregroundColor(bar.isCurrentPeriod ? .textSecondary : .textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: DS.spacing4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundColor(.textFaint)
        }
    }
}
