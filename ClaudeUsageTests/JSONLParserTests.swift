import XCTest
@testable import ClaudeUsage

final class JSONLParserTests: XCTestCase {
    var tempDir: URL!
    let parser = JSONLParser()

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func writeJSONL(_ content: String) -> URL {
        let url = tempDir.appendingPathComponent("\(UUID().uuidString).jsonl")
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testParsesValidJSONL() {
        let line = #"{"timestamp":"2026-01-01T00:00:00Z","sessionId":"s1","requestId":"r1","costUSD":0.01,"message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}"#
        let url = writeJSONL(line)
        let entries = parser.parse(files: [url])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].costUSD, 0.01)
        XCTAssertEqual(entries[0].message?.usage?.inputTokens, 100)
    }

    func testSkipsMalformedLines() {
        let content = """
        {"timestamp":"2026-01-01T00:00:00Z","costUSD":0.01}
        NOT VALID JSON {{{
        {"timestamp":"2026-01-02T00:00:00Z","costUSD":0.02}
        """
        let url = writeJSONL(content)
        let entries = parser.parse(files: [url])
        XCTAssertEqual(entries.count, 2)
    }

    func testSkipsErrorMessages() {
        let content = """
        {"timestamp":"2026-01-01T00:00:00Z","isApiErrorMessage":true,"costUSD":0.01}
        {"timestamp":"2026-01-02T00:00:00Z","costUSD":0.02}
        """
        let url = writeJSONL(content)
        let entries = parser.parse(files: [url])
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].costUSD, 0.02)
    }

    func testDeduplicatesByMessageIdAndRequestId() {
        let line = #"{"timestamp":"2026-01-01T00:00:00Z","requestId":"r1","message":{"id":"m1"}}"#
        let url1 = writeJSONL(line)
        let url2 = writeJSONL(line)
        let entries = parser.parse(files: [url1, url2])
        XCTAssertEqual(entries.count, 1)
    }

    func testHandlesEmptyFile() {
        let url = writeJSONL("")
        let entries = parser.parse(files: [url])
        XCTAssertEqual(entries.count, 0)
    }
}
