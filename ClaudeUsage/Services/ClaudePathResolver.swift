import Foundation

class ClaudePathResolver {
    /// Optionally inject environment for testing (since ProcessInfo.environment is immutable after launch)
    var environmentOverride: [String: String]? = nil

    private var environment: [String: String] {
        environmentOverride ?? ProcessInfo.processInfo.environment
    }

    func resolveJSONLFiles() -> [URL] {
        var basePaths: [URL] = []

        // 1. Check CLAUDE_CONFIG_DIR env var (comma-separated)
        if let envValue = environment["CLAUDE_CONFIG_DIR"] {
            let paths = envValue.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            for path in paths where !path.isEmpty {
                basePaths.append(URL(fileURLWithPath: path).appendingPathComponent("projects"))
            }
        }

        // 2. XDG standard path
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        basePaths.append(homeDir.appendingPathComponent(".config/claude/projects"))

        // 3. Legacy default path
        basePaths.append(homeDir.appendingPathComponent(".claude/projects"))

        var result: [URL] = []
        let fm = FileManager.default

        for base in basePaths {
            guard fm.fileExists(atPath: base.path) else { continue }
            guard let enumerator = fm.enumerator(
                at: base,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "jsonl" {
                    result.append(fileURL)
                }
            }
        }

        return result.sorted { $0.path < $1.path }
    }
}
