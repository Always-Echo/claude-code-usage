import Foundation

struct ModelBreakdown: Identifiable {
    let id = UUID()
    let modelName: String
    let totalTokens: Int
    let costUSD: Double
    let costRatio: Double
}
