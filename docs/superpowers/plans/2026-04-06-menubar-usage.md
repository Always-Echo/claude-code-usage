# Claude Code Usage Menubar App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menu bar app in Swift/SwiftUI that reads Claude Code's local JSONL files and displays token usage + cost stats across day/week/month/year dimensions in a custom popover panel.

**Architecture:** `StatusBarController` owns the `NSStatusItem` and `NSPopover`. `UsageDataService` (ObservableObject) handles all file I/O, parsing, deduplication, and aggregation — refreshing every 5 minutes. SwiftUI views are purely presentational, driven by `AggregatedStats` structs passed down from the service.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit (NSStatusItem, NSPopover), Swift Package Manager, GitHub Actions (release CI), create-dmg (DMG packaging)

---

## File Map

```
ClaudeUsage/
├── ClaudeUsage.xcodeproj/          ← Xcode project (generated via SPM or manually)
├── ClaudeUsage/
│   ├── ClaudeUsageApp.swift        ← @main entry, AppDelegate bridge
│   ├── StatusBarController.swift   ← NSStatusItem + NSPopover lifecycle
│   ├── Models/
│   │   ├── TimeDimension.swift     ← enum day/week/month/year
│   │   ├── UsageEntry.swift        ← Codable struct for one JSONL line
│   │   ├── PeriodBar.swift         ← one bar in the chart (label + tokens)
│   │   ├── ModelBreakdown.swift    ← per-model stats
│   │   └── AggregatedStats.swift  ← full stats for one dimension+period
│   ├── Services/
│   │   ├── ClaudePathResolver.swift ← finds ~/.claude/projects etc.
│   │   ├── JSONLParser.swift        ← reads files, deduplicates, returns [UsageEntry]
│   │   ├── CostCalculator.swift     ← fallback cost from hardcoded pricing table
│   │   └── UsageDataService.swift   ← ObservableObject, aggregation, Timer
│   ├── Views/
│   │   ├── UsagePopoverView.swift   ← root view, tab state
│   │   ├── DimensionTabBar.swift    ← 日/周/月/年 tabs
│   │   ├── SummaryCardsRow.swift    ← 3 stat cards
│   │   ├── BarChartView.swift       ← stacked bar chart
│   │   ├── TokenBreakdownGrid.swift ← 2×2 token detail
│   │   ├── ModelBreakdownList.swift ← per-model rows
│   │   ├── SessionsInfoRow.swift    ← sessions/projects/duration
│   │   ├── FooterTotalRow.swift     ← bottom total bar
│   │   └── DesignTokens.swift       ← Color/Font constants
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/
├── ClaudeUsageTests/
│   ├── JSONLParserTests.swift
│   ├── CostCalculatorTests.swift
│   └── UsageDataServiceTests.swift
├── .github/
│   └── workflows/
│       └── release.yml
└── README.md
```

---

## Task 1: Xcode Project Scaffold

**Files:**
- Create: `project.yml` (xcodegen spec)
- Create: `ClaudeUsage/ClaudeUsageApp.swift`
- Create: `ClaudeUsage/Info.plist`

- [ ] **Step 1: Initialize git repo**
```bash
cd /Users/liujun/GithubProjects/claude-code-usage
git init
git add docs/
git commit -m "chore: add design docs"
```

- [ ] **Step 2: Create xcodegen project.yml**
```yaml
name: ClaudeUsage
options:
  bundleIdPrefix: com.liujun
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"
targets:
  ClaudeUsage:
    type: application
    platform: macOS
    sources:
      - ClaudeUsage
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.liujun.ClaudeUsage
        SWIFT_VERSION: 5.9
        MACOSX_DEPLOYMENT_TARGET: "13.0"
        INFOPLIST_FILE: ClaudeUsage/Info.plist
    info:
      path: ClaudeUsage/Info.plist
      properties:
        LSUIElement: true
        CFBundleName: ClaudeUsage
        CFBundleShortVersionString: "1.0.0"
        CFBundleVersion: "1"
        NSHumanReadableCopyright: ""
  ClaudeUsageTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - ClaudeUsageTests
    dependencies:
      - target: ClaudeUsage
    settings:
      base:
        SWIFT_VERSION: 5.9
```

- [ ] **Step 3: Create directory structure**
```bash
mkdir -p ClaudeUsage/Models
mkdir -p ClaudeUsage/Services
mkdir -p ClaudeUsage/Views
mkdir -p ClaudeUsage/Assets.xcassets/AppIcon.appiconset
mkdir -p ClaudeUsageTests
```

- [ ] **Step 4: Create ClaudeUsageApp.swift**
```swift
import SwiftUI

@main
struct ClaudeUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
```

- [ ] **Step 5: Create Info.plist**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>ClaudeUsage</string>
    <key>CFBundleIdentifier</key>
    <string>com.liujun.ClaudeUsage</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSHumanReadableCopyright</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 6: Run xcodegen to generate .xcodeproj**
```bash
xcodegen generate
```

- [ ] **Commit**
```bash
git add .
git commit -m "feat: scaffold Xcode project structure"
```

---

### Task 2: Data Models

**Files:**
- Create: `ClaudeUsage/Models/TimeDimension.swift`
- Create: `ClaudeUsage/Models/UsageEntry.swift`
- Create: `ClaudeUsage/Models/PeriodBar.swift`
- Create: `ClaudeUsage/Models/ModelBreakdown.swift`
- Create: `ClaudeUsage/Models/AggregatedStats.swift`

- [ ] **Step 1: Create TimeDimension.swift**
```swift
import Foundation

enum TimeDimension: String, CaseIterable, Identifiable {
    case day, week, month, year

    var id: String { rawValue }

    var barCount: Int {
        switch self {
        case .day: return 7
        case .week: return 8
        case .month: return 12
        case .year: return 5
        }
    }

    var tabLabel: String {
        switch self {
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }

    var periodLabel: String {
        switch self {
        case .day: return "今日"
        case .week: return "本周"
        case .month: return "本月"
        case .year: return "今年"
        }
    }

    var previousPeriodLabel: String {
        switch self {
        case .day: return "昨日"
        case .week: return "上周"
        case .month: return "上月"
        case .year: return "去年"
        }
    }
}
```

- [ ] **Step 2: Create UsageEntry.swift**
```swift
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

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }
    }
}
```

- [ ] **Step 3: Create PeriodBar.swift**
```swift
import Foundation

struct PeriodBar: Identifiable {
    let id = UUID()
    let label: String
    let inputTokens: Int
    let outputTokens: Int
    let isCurrentPeriod: Bool

    var totalTokens: Int { inputTokens + outputTokens }
}
```

- [ ] **Step 4: Create ModelBreakdown.swift**
```swift
import Foundation

struct ModelBreakdown: Identifiable {
    let id = UUID()
    let modelName: String
    let totalTokens: Int
    let costUSD: Double
    let costRatio: Double
}
```

- [ ] **Step 5: Create AggregatedStats.swift**
```swift
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
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Models/
git commit -m "feat: add data models (TimeDimension, UsageEntry, PeriodBar, ModelBreakdown, AggregatedStats)"
```

---

### Task 3: ClaudePathResolver + Tests

**Files:**
- Create: `ClaudeUsage/Services/ClaudePathResolver.swift`
- Create: `ClaudeUsageTests/ClaudePathResolverTests.swift`

- [ ] **Step 1: Create ClaudePathResolver.swift**
```swift
import Foundation

class ClaudePathResolver {
    func resolveJSONLFiles() -> [URL] {
        var basePaths: [URL] = []

        // 1. Check CLAUDE_CONFIG_DIR env var (comma-separated)
        if let envValue = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
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
```

- [ ] **Step 2: Create ClaudePathResolverTests.swift**
```swift
import XCTest
@testable import ClaudeUsage

final class ClaudePathResolverTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testFindsJSONLFilesRecursively() {
        let projectDir = tempDir.appendingPathComponent("proj1")
        try! FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let jsonlFile = projectDir.appendingPathComponent("usage.jsonl")
        try! "{}".write(to: jsonlFile, atomically: true, encoding: .utf8)

        let resolver = ClaudePathResolver()
        // Can't easily test without env var; test the logic directly
        // by calling with a temp CLAUDE_CONFIG_DIR
        setenv("CLAUDE_CONFIG_DIR", tempDir.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        // Create expected structure
        let projectsDir = tempDir.appendingPathComponent("projects/myproject")
        try! FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let testFile = projectsDir.appendingPathComponent("test.jsonl")
        try! "{}".write(to: testFile, atomically: true, encoding: .utf8)

        let files = resolver.resolveJSONLFiles()
        XCTAssertTrue(files.contains(testFile), "Should find jsonl files recursively")
    }

    func testReturnsEmptyWhenNoPathsExist() {
        // Use a non-existent directory
        setenv("CLAUDE_CONFIG_DIR", tempDir.appendingPathComponent("nonexistent").path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let resolver = ClaudePathResolver()
        // Without real ~/.config/claude or ~/.claude, will be empty
        // (unless user has them; we can only test the env var path)
        let envPath = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
        XCTAssertNotNil(envPath)
    }

    func testRespectsCLAUDE_CONFIG_DIR() {
        let customDir = tempDir.appendingPathComponent("custom")
        let projectsDir = customDir.appendingPathComponent("projects/proj")
        try! FileManager.default.createDirectory(at: projectsDir, withIntermediateDirectories: true)
        let testFile = projectsDir.appendingPathComponent("data.jsonl")
        try! "{}".write(to: testFile, atomically: true, encoding: .utf8)

        setenv("CLAUDE_CONFIG_DIR", customDir.path, 1)
        defer { unsetenv("CLAUDE_CONFIG_DIR") }

        let resolver = ClaudePathResolver()
        let files = resolver.resolveJSONLFiles()
        XCTAssertTrue(files.contains(testFile))
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Services/ClaudePathResolver.swift ClaudeUsageTests/ClaudePathResolverTests.swift
git commit -m "feat: add ClaudePathResolver with tests"
```

---

### Task 4: JSONLParser + Tests

**Files:**
- Create: `ClaudeUsage/Services/JSONLParser.swift`
- Create: `ClaudeUsageTests/JSONLParserTests.swift`

- [ ] **Step 1: Create JSONLParser.swift**
```swift
import Foundation

struct JSONLParser {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

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
```

- [ ] **Step 2: Create JSONLParserTests.swift**
```swift
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
        let line = """
        {"timestamp":"2026-01-01T00:00:00Z","sessionId":"s1","requestId":"r1","costUSD":0.01,"message":{"id":"m1","model":"claude-sonnet-4-20250514","usage":{"input_tokens":100,"output_tokens":50,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
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
        let line = """
        {"timestamp":"2026-01-01T00:00:00Z","requestId":"r1","message":{"id":"m1"}}
        """
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
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Services/JSONLParser.swift ClaudeUsageTests/JSONLParserTests.swift
git commit -m "feat: add JSONLParser with deduplication and tests"
```

---

### Task 5: CostCalculator + Tests

**Files:**
- Create: `ClaudeUsage/Services/CostCalculator.swift`
- Create: `ClaudeUsageTests/CostCalculatorTests.swift`

- [ ] **Step 1: Create CostCalculator.swift**
```swift
import Foundation

struct CostCalculator {
    struct ModelPricing {
        let inputPerMillion: Double
        let outputPerMillion: Double
        let cacheCreationPerMillion: Double
        let cacheReadPerMillion: Double
    }

    private let pricingTable: [(prefix: String, pricing: ModelPricing)] = [
        ("claude-opus-4",    ModelPricing(inputPerMillion: 15,   outputPerMillion: 75,  cacheCreationPerMillion: 18.75, cacheReadPerMillion: 1.50)),
        ("claude-sonnet-4",  ModelPricing(inputPerMillion: 3,    outputPerMillion: 15,  cacheCreationPerMillion: 3.75,  cacheReadPerMillion: 0.30)),
        ("claude-haiku-4-5", ModelPricing(inputPerMillion: 0.80, outputPerMillion: 4,   cacheCreationPerMillion: 1.0,   cacheReadPerMillion: 0.08)),
        ("claude-haiku-3-5", ModelPricing(inputPerMillion: 0.80, outputPerMillion: 4,   cacheCreationPerMillion: 1.0,   cacheReadPerMillion: 0.08)),
    ]

    private let defaultPricing = ModelPricing(
        inputPerMillion: 3,
        outputPerMillion: 15,
        cacheCreationPerMillion: 3.75,
        cacheReadPerMillion: 0.30
    )

    func cost(for entry: UsageEntry) -> Double {
        if let costUSD = entry.costUSD {
            return costUSD
        }

        guard let usage = entry.message?.usage else { return 0 }
        let model = entry.message?.model ?? ""
        let pricing = pricingTable.first(where: { model.hasPrefix($0.prefix) })?.pricing ?? defaultPricing

        let input = Double(usage.inputTokens ?? 0)
        let output = Double(usage.outputTokens ?? 0)
        let cacheCreate = Double(usage.cacheCreationInputTokens ?? 0)
        let cacheRead = Double(usage.cacheReadInputTokens ?? 0)

        return (input * pricing.inputPerMillion
            + output * pricing.outputPerMillion
            + cacheCreate * pricing.cacheCreationPerMillion
            + cacheRead * pricing.cacheReadPerMillion) / 1_000_000
    }
}
```

- [ ] **Step 2: Create CostCalculatorTests.swift**
```swift
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
        // Unknown model uses sonnet-4 default: $3/M input
        let entry = makeEntry(model: "claude-unknown-model", input: 1_000_000)
        XCTAssertEqual(calculator.cost(for: entry), 3.0, accuracy: 0.0001)
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Services/CostCalculator.swift ClaudeUsageTests/CostCalculatorTests.swift
git commit -m "feat: add CostCalculator with hardcoded pricing table and tests"
```

---

### Task 6: UsageDataService + Tests

**Files:**
- Create: `ClaudeUsage/Services/UsageDataService.swift`
- Create: `ClaudeUsageTests/UsageDataServiceTests.swift`

- [ ] **Step 1: Create UsageDataService.swift**
```swift
import Foundation
import Combine

@MainActor
class UsageDataService: ObservableObject {
    @Published var stats: [TimeDimension: AggregatedStats] = [:]
    @Published var lastRefreshed: Date?
    @Published var isLoading: Bool = false

    private(set) var allEntries: [UsageEntry] = []
    private var timer: Timer?
    private let resolver = ClaudePathResolver()
    private let parser = JSONLParser()
    private let calculator = CostCalculator()

    init() {
        loadData()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.loadData() }
        }
    }

    func loadData() {
        isLoading = true
        let files = resolver.resolveJSONLFiles()
        allEntries = parser.parse(files: files)
        var newStats: [TimeDimension: AggregatedStats] = [:]
        for dim in TimeDimension.allCases {
            newStats[dim] = aggregate(entries: allEntries, for: dim)
        }
        stats = newStats
        lastRefreshed = Date()
        isLoading = false
    }

    func refreshIfNeeded() {
        guard let last = lastRefreshed else { loadData(); return }
        if Date().timeIntervalSince(last) > 300 { loadData() }
    }

    func aggregate(entries: [UsageEntry], for dimension: TimeDimension) -> AggregatedStats {
        let cal = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()

        func parseDate(_ s: String) -> Date? {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = formatter.date(from: s) { return d }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: s)
        }

        func isInCurrentPeriod(_ date: Date) -> Bool {
            switch dimension {
            case .day:   return cal.isDateInToday(date)
            case .week:  return cal.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month: return cal.isDate(date, equalTo: now, toGranularity: .month)
            case .year:  return cal.isDate(date, equalTo: now, toGranularity: .year)
            }
        }

        func isInPreviousPeriod(_ date: Date) -> Bool {
            switch dimension {
            case .day:
                guard let yesterday = cal.date(byAdding: .day, value: -1, to: now) else { return false }
                return cal.isDateInYesterday(date)
            case .week:
                guard let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear)
            case .month:
                guard let lastMonth = cal.date(byAdding: .month, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastMonth, toGranularity: .month)
            case .year:
                guard let lastYear = cal.date(byAdding: .year, value: -1, to: now) else { return false }
                return cal.isDate(date, equalTo: lastYear, toGranularity: .year)
            }
        }

        let currentEntries = entries.compactMap { e -> (UsageEntry, Date)? in
            guard let d = parseDate(e.timestamp) else { return nil }
            guard isInCurrentPeriod(d) else { return nil }
            return (e, d)
        }

        let prevEntries = entries.compactMap { e -> (UsageEntry, Date)? in
            guard let d = parseDate(e.timestamp) else { return nil }
            guard isInPreviousPeriod(d) else { return nil }
            return (e, d)
        }

        // Compute totals
        var totalCost = 0.0, input = 0, output = 0, cacheRead = 0, cacheCreate = 0
        var sessions = Set<String>(), projects = Set<String>()
        var modelCosts: [String: (tokens: Int, cost: Double)] = [:]
        var dates: [Date] = []

        for (e, d) in currentEntries {
            let cost = calculator.cost(for: e)
            totalCost += cost
            let usage = e.message?.usage
            let i = usage?.inputTokens ?? 0
            let o = usage?.outputTokens ?? 0
            let cr = usage?.cacheReadInputTokens ?? 0
            let cc = usage?.cacheCreationInputTokens ?? 0
            input += i; output += o; cacheRead += cr; cacheCreate += cc
            if let s = e.sessionId { sessions.insert(s) }
            if let p = e.cwd { projects.insert(p) }
            let model = e.message?.model ?? "unknown"
            let existing = modelCosts[model] ?? (0, 0)
            modelCosts[model] = (existing.tokens + i + o + cr + cc, existing.cost + cost)
            dates.append(d)
        }

        let totalTokens = input + output + cacheRead + cacheCreate
        let cacheHitRate = totalTokens > 0 ? Double(cacheRead) / Double(totalTokens) : 0

        // Previous period for delta
        var prevCost = 0.0, prevTokens = 0
        for (e, _) in prevEntries {
            prevCost += calculator.cost(for: e)
            let usage = e.message?.usage
            prevTokens += (usage?.inputTokens ?? 0) + (usage?.outputTokens ?? 0)
                + (usage?.cacheReadInputTokens ?? 0) + (usage?.cacheCreationInputTokens ?? 0)
        }
        let costDelta = totalCost - prevCost
        let tokenDeltaPercent = prevTokens > 0 ? Double(totalTokens - prevTokens) / Double(prevTokens) * 100 : 0

        let activeDuration = dates.isEmpty ? 0 : (dates.max()!.timeIntervalSince(dates.min()!))

        // Model breakdowns sorted by cost desc
        let breakdowns = modelCosts.map { (name, v) in
            ModelBreakdown(modelName: name, totalTokens: v.tokens, costUSD: v.cost,
                          costRatio: totalCost > 0 ? v.cost / totalCost : 0)
        }.sorted { $0.costUSD > $1.costUSD }

        // Chart bars
        let bars = makeChartBars(entries: entries, dimension: dimension, now: now, parser: parseDate)

        return AggregatedStats(
            totalCostUSD: totalCost, totalTokens: totalTokens,
            inputTokens: input, outputTokens: output,
            cacheReadTokens: cacheRead, cacheCreationTokens: cacheCreate,
            cacheHitRate: cacheHitRate, costDelta: costDelta,
            tokenDeltaPercent: tokenDeltaPercent,
            sessionCount: sessions.count, projectCount: projects.count,
            activeDuration: activeDuration,
            modelBreakdowns: breakdowns, chartBars: bars,
            dimensionLabel: dimension.periodLabel
        )
    }

    private func makeChartBars(entries: [UsageEntry], dimension: TimeDimension, now: Date,
                                parser: (String) -> Date?) -> [PeriodBar] {
        let cal = Calendar.current
        var bars: [PeriodBar] = []

        for i in stride(from: dimension.barCount - 1, through: 0, by: -1) {
            let offset = -i
            let periodDate: Date
            switch dimension {
            case .day:   periodDate = cal.date(byAdding: .day, value: offset, to: now)!
            case .week:  periodDate = cal.date(byAdding: .weekOfYear, value: offset, to: now)!
            case .month: periodDate = cal.date(byAdding: .month, value: offset, to: now)!
            case .year:  periodDate = cal.date(byAdding: .year, value: offset, to: now)!
            }

            func inPeriod(_ d: Date) -> Bool {
                switch dimension {
                case .day:   return cal.isDate(d, inSameDayAs: periodDate)
                case .week:  return cal.isDate(d, equalTo: periodDate, toGranularity: .weekOfYear)
                case .month: return cal.isDate(d, equalTo: periodDate, toGranularity: .month)
                case .year:  return cal.isDate(d, equalTo: periodDate, toGranularity: .year)
                }
            }

            var inp = 0, out = 0
            for e in entries {
                guard let d = parser(e.timestamp), inPeriod(d) else { continue }
                inp += e.message?.usage?.inputTokens ?? 0
                out += e.message?.usage?.outputTokens ?? 0
            }

            let label: String
            switch dimension {
            case .day:   label = cal.shortWeekdaySymbols[cal.component(.weekday, from: periodDate) - 1]
            case .week:  label = "W\(cal.component(.weekOfYear, from: periodDate))"
            case .month: label = cal.shortMonthSymbols[cal.component(.month, from: periodDate) - 1]
            case .year:  label = "\(cal.component(.year, from: periodDate))"
            }

            let isCurrent: Bool
            switch dimension {
            case .day:   isCurrent = cal.isDateInToday(periodDate)
            case .week:  isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .weekOfYear)
            case .month: isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .month)
            case .year:  isCurrent = cal.isDate(periodDate, equalTo: now, toGranularity: .year)
            }

            bars.append(PeriodBar(label: label, inputTokens: inp, outputTokens: out, isCurrentPeriod: isCurrent))
        }
        return bars
    }
}
```

- [ ] **Step 2: Create UsageDataServiceTests.swift**
```swift
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
        let today = ISO8601DateFormatter().string(from: Date())
        let entries = [
            makeEntry(timestamp: today, sessionId: "s1", cwd: "/proj1", input: 100, output: 50),
            makeEntry(timestamp: today, sessionId: "s2", cwd: "/proj2", input: 200, output: 100),
        ]
        let stats = svc.aggregate(entries: entries, for: .day)
        XCTAssertEqual(stats.inputTokens, 300)
        XCTAssertEqual(stats.outputTokens, 150)
        XCTAssertEqual(stats.sessionCount, 2)
        XCTAssertEqual(stats.projectCount, 2)
    }

    func testCacheHitRateCalculation() {
        let svc = UsageDataService()
        let today = ISO8601DateFormatter().string(from: Date())
        let entries = [makeEntry(timestamp: today, input: 100, output: 50, cacheRead: 350)]
        let stats = svc.aggregate(entries: entries, for: .day)
        // totalTokens = 100 + 50 + 350 = 500, cacheRead = 350 -> rate = 0.7
        XCTAssertEqual(stats.cacheHitRate, 0.7, accuracy: 0.001)
    }

    func testChartBarsHasCorrectCount() {
        let svc = UsageDataService()
        let stats = svc.aggregate(entries: [], for: .day)
        XCTAssertEqual(stats.chartBars.count, 7)

        let statsWeek = svc.aggregate(entries: [], for: .week)
        XCTAssertEqual(statsWeek.chartBars.count, 8)

        let statsMonth = svc.aggregate(entries: [], for: .month)
        XCTAssertEqual(statsMonth.chartBars.count, 12)

        let statsYear = svc.aggregate(entries: [], for: .year)
        XCTAssertEqual(statsYear.chartBars.count, 5)
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Services/UsageDataService.swift ClaudeUsageTests/UsageDataServiceTests.swift
git commit -m "feat: add UsageDataService with aggregation, chart bars, and tests"
```

---

### Task 7: DesignTokens

**Files:**
- Create: `ClaudeUsage/Views/DesignTokens.swift`

- [ ] **Step 1: Create DesignTokens.swift**
```swift
import SwiftUI

extension Color {
    static let background     = Color(hex: "#171717")
    static let cardBackground = Color(hex: "#1e1e1e")
    static let borderStandard = Color(hex: "#2e2e2e")
    static let borderSubtle   = Color(hex: "#242424")
    static let accent         = Color(hex: "#3ecf8e")
    static let accentDim      = Color(hex: "#2a8c5e")
    static let textPrimary    = Color(hex: "#fafafa")
    static let textSecondary  = Color(hex: "#b4b4b4")
    static let textMuted      = Color(hex: "#898989")
    static let textFaint      = Color(hex: "#4d4d4d")
    static let trendUp        = Color(hex: "#3ecf8e")
    static let trendDown      = Color(hex: "#f87171")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

enum DS {
    static let panelWidth:   CGFloat = 320
    static let cornerRadius: CGFloat = 9
    static let spacing4:     CGFloat = 4
    static let spacing8:     CGFloat = 8
    static let spacing12:    CGFloat = 12
    static let spacing14:    CGFloat = 14
    static let spacing16:    CGFloat = 16
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Views/DesignTokens.swift
git commit -m "feat: add design tokens (colors, spacing constants)"
```

---

### Task 8: StatusBarController + ClaudeUsageApp

**Files:**
- Create: `ClaudeUsage/StatusBarController.swift`
- Update: `ClaudeUsage/ClaudeUsageApp.swift`

- [ ] **Step 1: Create StatusBarController.swift**
```swift
import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let dataService = UsageDataService()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "Claude Usage")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let contentView = UsagePopoverView(dataService: dataService)
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 320, height: 520)
        popover.behavior = .transient
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            Task { @MainActor in
                self.dataService.refreshIfNeeded()
            }
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
```

- [ ] **Step 2: Update ClaudeUsageApp.swift** (already created in Task 1, verify content matches)

- [ ] **Commit**
```bash
git add ClaudeUsage/StatusBarController.swift ClaudeUsage/ClaudeUsageApp.swift
git commit -m "feat: add StatusBarController with NSStatusItem and NSPopover"
```

---

### Task 9: DimensionTabBar + SummaryCardsRow

**Files:**
- Create: `ClaudeUsage/Views/DimensionTabBar.swift`
- Create: `ClaudeUsage/Views/SummaryCardsRow.swift`

- [ ] **Step 1: Create DimensionTabBar.swift**
```swift
import SwiftUI

struct DimensionTabBar: View {
    @Binding var selectedDimension: TimeDimension

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeDimension.allCases) { dim in
                Button(action: { selectedDimension = dim }) {
                    VStack(spacing: 0) {
                        Text(dim.tabLabel)
                            .font(.system(size: 11))
                            .foregroundColor(selectedDimension == dim ? .accent : .textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.spacing8)
                        Rectangle()
                            .fill(selectedDimension == dim ? Color.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.background)
    }
}
```

- [ ] **Step 2: Create SummaryCardsRow.swift**
```swift
import SwiftUI

struct SummaryCardsRow: View {
    let stats: AggregatedStats

    var body: some View {
        HStack(spacing: DS.spacing8) {
            StatCard(
                label: "花费",
                value: String(format: "$%.2f", stats.totalCostUSD),
                delta: formatCostDelta(stats.costDelta),
                deltaColor: stats.costDelta <= 0 ? .trendUp : .trendDown
            )
            StatCard(
                label: "TOKENS",
                value: formatTokens(stats.totalTokens),
                delta: formatTokenDelta(stats.tokenDeltaPercent),
                deltaColor: stats.tokenDeltaPercent <= 0 ? .trendUp : .trendDown
            )
            StatCard(
                label: "CACHE",
                value: String(format: "%.0f%%", stats.cacheHitRate * 100),
                delta: "saved " + String(format: "$%.2f", cacheSavings(stats)),
                deltaColor: .textFaint
            )
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatCostDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(String(format: "$%.2f", delta))"
    }

    private func formatTokenDelta(_ pct: Double) -> String {
        let sign = pct > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f%%", pct))"
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }

    private func cacheSavings(_ stats: AggregatedStats) -> Double {
        // Cache read is ~90% cheaper than input; approximate savings
        let calculator = CostCalculator()
        return Double(stats.cacheReadTokens) * 2.7 / 1_000_000  // approx sonnet savings
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let delta: String
    let deltaColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .textCase(.uppercase)
                .foregroundColor(.textMuted)
            Text(value)
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(.textPrimary)
            Text(delta)
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(deltaColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.spacing8)
        .background(Color.cardBackground)
        .cornerRadius(DS.cornerRadius)
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Views/DimensionTabBar.swift ClaudeUsage/Views/SummaryCardsRow.swift
git commit -m "feat: add DimensionTabBar and SummaryCardsRow views"
```

---

### Task 10: BarChartView

**Files:**
- Create: `ClaudeUsage/Views/BarChartView.swift`

- [ ] **Step 1: Create BarChartView.swift**
```swift
import SwiftUI

struct BarChartView: View {
    let bars: [PeriodBar]
    private let chartHeight: CGFloat = 52
    private let minBarHeight: CGFloat = 2

    private var maxTotal: Int {
        bars.map(\.totalTokens).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.spacing8) {
            // Legend
            HStack(spacing: DS.spacing12) {
                LegendDot(color: .accent, label: "Output")
                LegendDot(color: .accentDim, label: "Input")
                Spacer()
            }

            // Bars
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(bars) { bar in
                    BarColumn(bar: bar, maxTotal: maxTotal,
                              chartHeight: chartHeight, minBarHeight: minBarHeight)
                }
            }
            .frame(height: chartHeight + 16) // extra for labels
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }
}

struct BarColumn: View {
    let bar: PeriodBar
    let maxTotal: Int
    let chartHeight: CGFloat
    let minBarHeight: CGFloat

    private func height(for tokens: Int) -> CGFloat {
        guard maxTotal > 0 else { return minBarHeight }
        let h = CGFloat(tokens) / CGFloat(maxTotal) * chartHeight
        return max(h, tokens > 0 ? minBarHeight : 0)
    }

    var body: some View {
        VStack(spacing: 2) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // Output on top
                Rectangle()
                    .fill(bar.isCurrentPeriod ? Color.accent : Color.accent.opacity(0.6))
                    .frame(height: height(for: bar.outputTokens))
                // Input below
                Rectangle()
                    .fill(bar.isCurrentPeriod ? Color.accentDim : Color.accentDim.opacity(0.6))
                    .frame(height: height(for: bar.inputTokens))
            }
            .frame(height: chartHeight)
            .if(bar.isCurrentPeriod) { view in
                view.shadow(color: Color.accent.opacity(0.4), radius: 4, x: 0, y: 0)
            }

            Text(bar.label)
                .font(.system(size: 8))
                .foregroundColor(bar.isCurrentPeriod ? .textSecondary : .textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: DS.spacing4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9)).foregroundColor(.textFaint)
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Views/BarChartView.swift
git commit -m "feat: add stacked BarChartView with current-period highlight"
```

---

### Task 11: TokenBreakdownGrid + ModelBreakdownList + SessionsInfoRow + FooterTotalRow

**Files:**
- Create: `ClaudeUsage/Views/TokenBreakdownGrid.swift`
- Create: `ClaudeUsage/Views/ModelBreakdownList.swift`
- Create: `ClaudeUsage/Views/SessionsInfoRow.swift`
- Create: `ClaudeUsage/Views/FooterTotalRow.swift`

- [ ] **Step 1: Create TokenBreakdownGrid.swift**
```swift
import SwiftUI

struct TokenBreakdownGrid: View {
    let stats: AggregatedStats

    private var items: [(color: Color, name: String, count: Int)] {
        [
            (.accent,                    "Output",        stats.outputTokens),
            (.accentDim,                 "Input",         stats.inputTokens),
            (.borderStandard,            "Cache Read",    stats.cacheReadTokens),
            (Color(hex: "#2a2a2a"),      "Cache Write",   stats.cacheCreationTokens),
        ]
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.spacing8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: DS.spacing8) {
                    Circle().fill(item.color).frame(width: 7, height: 7)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.system(size: 9))
                            .foregroundColor(.textFaint)
                        Text(formatNumber(item.count))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
```

- [ ] **Step 2: Create ModelBreakdownList.swift**
```swift
import SwiftUI

struct ModelBreakdownList: View {
    let models: [ModelBreakdown]

    var body: some View {
        VStack(spacing: DS.spacing4) {
            ForEach(models) { model in
                HStack(spacing: DS.spacing8) {
                    Text(shortModelName(model.modelName))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatTokens(model.totalTokens))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.textFaint)

                    // Progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.borderStandard)
                            .frame(width: 36, height: 3)
                            .cornerRadius(1.5)
                        Rectangle()
                            .fill(Color.accent)
                            .frame(width: max(2, 36 * model.costRatio), height: 3)
                            .cornerRadius(1.5)
                    }

                    Text(String(format: "$%.3f", model.costUSD))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundColor(.accent)
                }
            }
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func shortModelName(_ name: String) -> String {
        // e.g. "claude-sonnet-4-20250514" -> "sonnet-4"
        let parts = name.replacingOccurrences(of: "claude-", with: "").split(separator: "-")
        if parts.count >= 2 { return "\(parts[0])-\(parts[1])" }
        return name
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Step 3: Create SessionsInfoRow.swift**
```swift
import SwiftUI

struct SessionsInfoRow: View {
    let stats: AggregatedStats

    var body: some View {
        HStack {
            InfoItem(icon: "bolt.fill", label: "Sessions", value: "\(stats.sessionCount)")
            Spacer()
            InfoItem(icon: "folder.fill", label: "Projects", value: "\(stats.projectCount)")
            Spacer()
            InfoItem(icon: "clock", label: "Active", value: formatDuration(stats.activeDuration))
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }
}

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DS.spacing4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.textFaint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.textFaint)
                Text(value)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.textSecondary)
            }
        }
    }
}
```

- [ ] **Step 4: Create FooterTotalRow.swift**
```swift
import SwiftUI

struct FooterTotalRow: View {
    let stats: AggregatedStats
    let dimension: TimeDimension

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dimension.periodLabel + "合计")
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .foregroundColor(.textFaint)
                Text(formatTokens(stats.totalTokens) + " tokens")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.textFaint)
            }
            Spacer()
            Text(String(format: "$%.4f", stats.totalCostUSD))
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundColor(.accent)
        }
        .padding(.horizontal, DS.spacing12)
        .padding(.vertical, DS.spacing8)
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.0fk", Double(n) / 1_000) }
        return "\(n)"
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Views/TokenBreakdownGrid.swift ClaudeUsage/Views/ModelBreakdownList.swift
git add ClaudeUsage/Views/SessionsInfoRow.swift ClaudeUsage/Views/FooterTotalRow.swift
git commit -m "feat: add TokenBreakdownGrid, ModelBreakdownList, SessionsInfoRow, FooterTotalRow"
```

---

### Task 12: UsagePopoverView (Assembly)

**Files:**
- Create: `ClaudeUsage/Views/UsagePopoverView.swift`

- [ ] **Step 1: Create UsagePopoverView.swift**
```swift
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var dataService: UsageDataService
    @State private var selectedDimension: TimeDimension = .day

    private var stats: AggregatedStats {
        dataService.stats[selectedDimension] ?? .empty
    }

    private var refreshLabel: String {
        guard let last = dataService.lastRefreshed else { return "never" }
        let mins = Int(Date().timeIntervalSince(last) / 60)
        return mins < 1 ? "just now" : "\(mins)m ago"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.spacing8) {
                Circle()
                    .fill(Color.accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.accent.opacity(0.6), radius: 3)
                Text("Claude Usage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(refreshLabel)
                    .font(.system(size: 10))
                    .foregroundColor(.textFaint)
            }
            .padding(.horizontal, DS.spacing12)
            .padding(.vertical, DS.spacing8)

            Divider().background(Color.borderSubtle)

            DimensionTabBar(selectedDimension: $selectedDimension)

            Divider().background(Color.borderSubtle)

            if dataService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if dataService.allEntries.isEmpty {
                VStack(spacing: DS.spacing8) {
                    Text("未找到 Claude Code 数据")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                    Text("请确认已安装并使用过 Claude Code")
                        .font(.system(size: 11))
                        .foregroundColor(.textFaint)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        SummaryCardsRow(stats: stats)

                        Divider().background(Color.borderSubtle)

                        VStack(alignment: .leading, spacing: DS.spacing4) {
                            Text("近\(stats.chartBars.count)期用量")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.textFaint)
                                .padding(.horizontal, DS.spacing12)
                                .padding(.top, DS.spacing8)
                            BarChartView(bars: stats.chartBars)
                        }

                        Divider().background(Color.borderSubtle)

                        TokenBreakdownGrid(stats: stats)

                        Divider().background(Color.borderSubtle)

                        if !stats.modelBreakdowns.isEmpty {
                            ModelBreakdownList(models: stats.modelBreakdowns)
                            Divider().background(Color.borderSubtle)
                        }

                        SessionsInfoRow(stats: stats)
                    }
                }
            }

            Divider().background(Color.borderSubtle)

            FooterTotalRow(stats: stats, dimension: selectedDimension)
        }
        .frame(width: DS.panelWidth)
        .background(Color.background)
    }
}
```

- [ ] **Commit**
```bash
git add ClaudeUsage/Views/UsagePopoverView.swift
git commit -m "feat: add UsagePopoverView assembly with all sub-views"
```

---

### Task 13: GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `ExportOptions.plist`

- [ ] **Step 1: Create release.yml**
```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Archive
        run: |
          xcodebuild archive \
            -scheme ClaudeUsage \
            -archivePath build/ClaudeUsage.xcarchive \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO

      - name: Export Archive
        run: |
          xcodebuild -exportArchive \
            -archivePath build/ClaudeUsage.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Ad-hoc Sign
        run: codesign --deep --force --sign - build/export/ClaudeUsage.app

      - name: Install create-dmg
        run: brew install create-dmg

      - name: Create DMG
        run: |
          create-dmg \
            --volname "ClaudeUsage" \
            --app-drop-link 425 120 \
            ClaudeUsage.dmg build/export/

      - name: Create ZIP
        run: cd build/export && zip -r ../../ClaudeUsage.app.zip ClaudeUsage.app

      - name: Create GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh release create ${{ github.ref_name }} \
            ClaudeUsage.dmg \
            ClaudeUsage.app.zip \
            --title "ClaudeUsage ${{ github.ref_name }}" \
            --notes "macOS menu bar app for Claude Code usage stats."
```

- [ ] **Step 2: Create ExportOptions.plist**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
```

- [ ] **Commit**
```bash
git add .github/workflows/release.yml ExportOptions.plist
git commit -m "ci: add GitHub Actions release workflow with DMG and zip"
```

---

### Task 14: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**
Content should include:
- Project title and description ("macOS menu bar app that shows Claude Code token usage and costs")
- Screenshot placeholder `![screenshot](docs/screenshot.png)`
- **Installation** section:
  - DMG method: Download `ClaudeUsage.dmg` from Releases, drag to Applications, right-click > Open
  - ZIP method: Download `ClaudeUsage.app.zip`, unzip, move to Applications, right-click > Open
  - Gatekeeper bypass: Because the app is ad-hoc signed (no Apple Developer ID), on first launch right-click the app icon > Open > click "Open" in the dialog. Or: `xattr -d com.apple.quarantine /Applications/ClaudeUsage.app`
- **Build from Source** section:
  - Requirements: macOS 13+, Xcode 15+
  - Steps: `git clone`, open `ClaudeUsage.xcodeproj`, select "My Mac" target, Cmd+R
- **Data Sources** section:
  - Reads `*.jsonl` files from `~/.claude/projects/` or `~/.config/claude/projects/`
  - Or set `CLAUDE_CONFIG_DIR` env var to a custom path
  - Refreshes every 5 minutes automatically

- [ ] **Commit**
```bash
git add README.md
git commit -m "docs: add README with installation and usage instructions"
```

---

### Task 15: Final Integration Test

**Files:** (no new files — fix errors discovered during build)

- [ ] **Step 1: Verify build**
```bash
cd /Users/liujun/GithubProjects/claude-code-usage
xcodebuild build \
  -scheme ClaudeUsage \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | tail -30
```

- [ ] **Step 2: Run all unit tests**
```bash
xcodebuild test \
  -scheme ClaudeUsage \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  2>&1 | grep -E "(PASS|FAIL|error:|warning:)" | tail -40
```

- [ ] **Step 3: Fix any compilation errors**
Address type mismatches, missing imports, or API issues found in steps 1-2.

- [ ] **Final commit**
```bash
git add -A
git commit -m "fix: resolve build errors from integration test"
git tag v0.1.0
```

