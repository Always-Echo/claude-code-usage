import XCTest
@testable import ClaudeUsage

final class ClaudePathResolverTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        let raw = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: raw, withIntermediateDirectories: true)
        tempDir = raw  // keep raw; we'll normalize in assertions
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    /// Normalize a path by resolving symlinks (handles /var -> /private/var)
    func norm(_ url: URL) -> String { url.resolvingSymlinksInPath().path }
    func normPaths(_ urls: [URL]) -> [String] { urls.map { norm($0) } }

    func testFindsJSONLFilesRecursively() {
        let projectsDir = tempDir.appendingPathComponent("projects/myproject")
        try! FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let testFile = projectsDir.appendingPathComponent("test.jsonl")
        try! "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let resolver = ClaudePathResolver()
        resolver.environmentOverride = ["CLAUDE_CONFIG_DIR": tempDir.path]
        let filePaths = normPaths(resolver.resolveJSONLFiles())
        XCTAssertTrue(filePaths.contains(norm(testFile)), "Should find jsonl files recursively. Got: \(filePaths)")
    }

    func testIgnoresNonJSONLFiles() {
        let projectsDir = tempDir.appendingPathComponent("projects/myproject")
        try! FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let txtFile = projectsDir.appendingPathComponent("notes.txt")
        try! "text".write(to: txtFile, atomically: true, encoding: .utf8)
        let jsonlFile = projectsDir.appendingPathComponent("data.jsonl")
        try! "{}".write(to: jsonlFile, atomically: true, encoding: .utf8)

        let resolver = ClaudePathResolver()
        resolver.environmentOverride = ["CLAUDE_CONFIG_DIR": tempDir.path]
        let filePaths = normPaths(resolver.resolveJSONLFiles())
        XCTAssertTrue(filePaths.contains(norm(jsonlFile)))
        XCTAssertFalse(filePaths.contains(norm(txtFile)))
    }

    func testRespectsCLAUDE_CONFIG_DIR() {
        let customDir = tempDir.appendingPathComponent("custom")
        let projectsDir = customDir.appendingPathComponent("projects/proj")
        try! FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let testFile = projectsDir.appendingPathComponent("data.jsonl")
        try! "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let resolver = ClaudePathResolver()
        resolver.environmentOverride = ["CLAUDE_CONFIG_DIR": customDir.path]
        let filePaths = normPaths(resolver.resolveJSONLFiles())
        XCTAssertTrue(filePaths.contains(norm(testFile)))
    }

    func testHandlesMultiplePathsInEnvVar() {
        let dir1 = tempDir.appendingPathComponent("dir1")
        let dir2 = tempDir.appendingPathComponent("dir2")
        let proj1 = dir1.appendingPathComponent("projects/p1")
        let proj2 = dir2.appendingPathComponent("projects/p2")
        try! FileManager.default.createDirectory(at: proj1, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: proj2, withIntermediateDirectories: true)
        let file1 = proj1.appendingPathComponent("a.jsonl")
        let file2 = proj2.appendingPathComponent("b.jsonl")
        try! "{}".write(to: file1, atomically: true, encoding: .utf8)
        try! "{}".write(to: file2, atomically: true, encoding: .utf8)

        let resolver = ClaudePathResolver()
        resolver.environmentOverride = ["CLAUDE_CONFIG_DIR": "\(dir1.path),\(dir2.path)"]
        let filePaths = normPaths(resolver.resolveJSONLFiles())
        XCTAssertTrue(filePaths.contains(norm(file1)), "Missing file1. Got: \(filePaths)")
        XCTAssertTrue(filePaths.contains(norm(file2)), "Missing file2. Got: \(filePaths)")
    }
}
