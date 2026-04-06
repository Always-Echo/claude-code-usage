import SwiftUI

struct TokenBreakdownGrid: View {
    let stats: AggregatedStats

    private var items: [(color: Color, name: String, count: Int)] {
        [
            (.accent,               "Output",      stats.outputTokens),
            (.accentDim,            "Input",        stats.inputTokens),
            (.borderStandard,       "Cache Read",   stats.cacheReadTokens),
            (Color(hex: "#2a2a2a"), "Cache Write",  stats.cacheCreationTokens),
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.spacing8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: DS.spacing8) {
                    Circle().fill(item.color).frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 9))
                            .foregroundColor(.textFaint)
                        Text(Formatters.formattedNumber(item.count))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

}
