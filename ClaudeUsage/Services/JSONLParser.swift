import Foundation

struct JSONLParser {
    private let decoder = JSONDecoder()

    func parse(files: [URL]) -> [UsageEntry] {
        var seen = Set<String>()
        var entries: [UsageEntry] = []

        for fileURL in files {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                guard let data = trimmed.data(using: .utf8),
                      let entry = try? decoder.decode(UsageEntry.self, from: data) else { continue }

                // Skip error messages
                if entry.isApiErrorMessage == true { continue }

                // Deduplication
                let msgId = entry.message?.id
                let reqId = entry.requestId
                if let m = msgId, let r = reqId {
                    let key = "\(m):\(r)"
                    if seen.contains(key) { continue }
                    seen.insert(key)
                }

                entries.append(entry)
            }
        }

        return entries.sorted { $0.timestamp < $1.timestamp }
    }
}
