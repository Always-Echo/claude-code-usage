import Foundation

struct UsageEntry: Codable {
    let timestamp: String
    let sessionId: String?
    let cwd: String?
    let requestId: String?
    let costUSD: Double?
    let isApiErrorMessage: Bool?
    let message: MessagePayload?

    struct MessagePayload: Codable {
        let id: String?
        let model: String?
        let usage: TokenUsage?
    }

    struct TokenUsage: Codable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?
        let speed: String?  // "standard" or "fast" — fast mode costs 5x

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case speed
        }
    }
}
