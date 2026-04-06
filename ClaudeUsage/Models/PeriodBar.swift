import Foundation

struct PeriodBar: Identifiable {
    let id = UUID()
    let label: String
    let inputTokens: Int
    let outputTokens: Int
    let isCurrentPeriod: Bool

    var totalTokens: Int { inputTokens + outputTokens }
}
