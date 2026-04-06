import XCTest
@testable import ClaudeUsage

@MainActor
final class UsageDataServiceTests: XCTestCase {
    func makeEntry(timestamp: String, sessionId: String? = nil, cwd: String? = nil,
                   model: String = "claude-sonnet-4-20250514",
                   input: Int = 100, output: Int = 50,
                   cacheRead: Int = 200, cacheCreate: Int = 0,
                   costUSD: Double? = nil) -> UsageEntry {
        let usage = UsageEntry.TokenUsage(inputTokens: input, outputTokens: output,
                                          cacheCreationInputTokens: cacheCreate,
                                          cacheReadInputTokens: cacheRead)
        let msg = UsageEntry.MessagePayload(id: UUID().uuidString, model: model, usage: usage)
        return UsageEntry(timestamp: timestamp, sessionId: sessionId, cwd: cwd,
                          requestId: UUID().uuidString, costUSD: costUSD,
                          isApiErrorMessage: nil, message: msg)
    }

    func testDayAggregationSumsCorrectly() {
        let svc = UsageDataService()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let today = formatter.string(from: Date())
        let entries = [
            makeEntry(timestamp: today, sessionId: "s1", cwd: "/proj1", input: 100, output: 50, cacheRead: 0),
            makeEntry(timestamp: today, sessionId: "s2", cwd: "/proj2", input: 200, output: 100, cacheRead: 0),
        ]
        let stats = svc.aggregate(entries: entries, for: .day)
        XCTAssertEqual(stats.inputTokens, 300)
        XCTAssertEqual(stats.outputTokens, 150)
        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.projectCount, 2)
    }

    func testCacheHitRateCalculation() {
        let svc = UsageDataService()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let today = formatter.string(from: Date())
        let entries = [makeEntry(timestamp: today, input: 100, output: 50, cacheRead: 350, cacheCreate: 0)]
        let stats = svc.aggregate(entries: entries, for: .day)
        // totalTokens = 100 + 50 + 350 = 500, cacheRead = 350 -> rate = 0.7
        XCTAssertEqual(stats.cacheHitRate, 0.7, accuracy: 0.001)
    }

    func testChartBarsHasCorrectCount() {
        let svc = UsageDataService()
        let statsDay = svc.aggregate(entries: [], for: .day)
        XCTAssertEqual(statsDay.chartBars.count, 7)

        let statsWeek = svc.aggregate(entries: [], for: .week)
        XCTAssertEqual(statsWeek.chartBars.count, 8)

        let statsMonth = svc.aggregate(entries: [], for: .month)
        XCTAssertEqual(statsMonth.chartBars.count, 12)

        let statsYear = svc.aggregate(entries: [], for: .year)
        XCTAssertEqual(statsYear.chartBars.count, 5)
    }
}
