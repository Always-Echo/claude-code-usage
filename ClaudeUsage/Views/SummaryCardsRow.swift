import SwiftUI

struct SummaryCardsRow: View {
    let stats: AggregatedStats

    var body: some View {
        HStack(spacing: DS.spacing8) {
            StatCard(
                label: "花费",
                value: String(format: "$%.2f", stats.totalCostUSD),
                delta: formatCostDelta(stats.costDelta),
                deltaColor: stats.costDelta <= 0 ? .trendUp : .trendDown
            )
            StatCard(
                label: "TOKENS",
                value: formatTokens(stats.totalTokens),
                delta: formatTokenDelta(stats.tokenDeltaPercent),
                deltaColor: stats.tokenDeltaPercent <= 0 ? .trendUp : .trendDown
            )
            StatCard(
                label: "CACHE",
                value: String(format: "%.0f%%", stats.cacheHitRate * 100),
                delta: "saved " + String(format: "$%.2f", cacheSavings(stats)),
                deltaColor: .textFaint
            )
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatCostDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(String(format: "$%.2f", delta))"
    }

    private func formatTokenDelta(_ pct: Double) -> String {
        let sign = pct > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f%%", pct))"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private func cacheSavings(_ stats: AggregatedStats) -> Double {
        // Approx savings: cache read vs full input cost (sonnet: $3 vs $0.30/M = $2.70/M savings)
        return Double(stats.cacheReadTokens) * 2.7 / 1_000_000
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let delta: String
    let deltaColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .foregroundColor(.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(.textPrimary)
            Text(delta)
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(deltaColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.spacing8)
        .background(Color.cardBackground)
        .cornerRadius(DS.cornerRadius)
    }
}
