import SwiftUI

struct ModelBreakdownList: View {
    let models: [ModelBreakdown]

    var body: some View {
        VStack(spacing: DS.spacing4) {
            ForEach(models) { model in
                HStack(spacing: DS.spacing8) {
                    Text(shortModelName(model.modelName))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTokens(model.totalTokens))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.textFaint)

                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.borderStandard)
                            .frame(width: 36, height: 3)
                            .cornerRadius(1.5)
                        Rectangle()
                            .fill(Color.accent)
                            .frame(width: max(2, 36 * model.costRatio), height: 3)
                            .cornerRadius(1.5)
                    }

                    Text(String(format: "$%.3f", model.costUSD))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func shortModelName(_ name: String) -> String {
        let parts = name.replacingOccurrences(of: "claude-", with: "").split(separator: "-")
        if parts.count >= 2 { return "\(parts[0])-\(parts[1])" }
        return name
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }
}
