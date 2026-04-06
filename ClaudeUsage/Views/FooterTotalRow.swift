import SwiftUI

struct FooterTotalRow: View {
    let stats: AggregatedStats
    let dimension: TimeDimension

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dimension.periodLabel + "合计")
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .foregroundColor(.textFaint)
                Text(Formatters.tokens(stats.totalTokens) + " tokens")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.textFaint)
            }
            Spacer()
            Text(String(format: "$%.4f", stats.totalCostUSD))
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundColor(.accent)
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

}
