import XCTest
@testable import ClaudeUsage

final class CostCalculatorTests: XCTestCase {
    let calculator = CostCalculator()

    func makeEntry(costUSD: Double? = nil, model: String = "claude-sonnet-4-20250514",
                   input: Int = 0, output: Int = 0, cacheCreate: Int = 0, cacheRead: Int = 0) -> UsageEntry {
        let usage = UsageEntry.TokenUsage(
            inputTokens: input, outputTokens: output,
            cacheCreationInputTokens: cacheCreate, cacheReadInputTokens: cacheRead
        )
        let message = UsageEntry.MessagePayload(id: "m1", model: model, usage: usage)
        return UsageEntry(timestamp: "2026-01-01T00:00:00Z", sessionId: nil, cwd: nil,
                          requestId: nil, costUSD: costUSD, isApiErrorMessage: nil, message: message)
    }

    func testUsesCostUSDWhenPresent() {
        let entry = makeEntry(costUSD: 0.0124)
        XCTAssertEqual(calculator.cost(for: entry), 0.0124, accuracy: 0.0001)
    }

    func testCalculatesFromTokensWhenCostUSDNil() {
        // 1M sonnet input = $3
        let entry = makeEntry(model: "claude-sonnet-4-20250514", input: 1_000_000)
        XCTAssertEqual(calculator.cost(for: entry), 3.0, accuracy: 0.0001)
    }

    func testHandlesOpusPricing() {
        // 1M opus input = $15
        let entry = makeEntry(model: "claude-opus-4-20250514", input: 1_000_000)
        XCTAssertEqual(calculator.cost(for: entry), 15.0, accuracy: 0.0001)
    }

    func testHandlesUnknownModelWithDefault() {
        // Unknown model uses default ($3/M input)
        let entry = makeEntry(model: "claude-unknown-model", input: 1_000_000)
        XCTAssertEqual(calculator.cost(for: entry), 3.0, accuracy: 0.0001)
    }
}
