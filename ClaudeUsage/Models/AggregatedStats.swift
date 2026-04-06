import Foundation

struct AggregatedStats {
    let totalCostUSD: Double
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let cacheHitRate: Double
    let costDelta: Double
    let tokenDeltaPercent: Double
    let sessionCount: Int
    let projectCount: Int
    let activeDuration: TimeInterval
    let modelBreakdowns: [ModelBreakdown]
    let chartBars: [PeriodBar]
    let dimensionLabel: String

    static let empty = AggregatedStats(
        totalCostUSD: 0, totalTokens: 0,
        inputTokens: 0, outputTokens: 0,
        cacheReadTokens: 0, cacheCreationTokens: 0,
        cacheHitRate: 0, costDelta: 0, tokenDeltaPercent: 0,
        sessionCount: 0, projectCount: 0, activeDuration: 0,
        modelBreakdowns: [], chartBars: [], dimensionLabel: ""
    )
}
