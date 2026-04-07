# ClaudeUsage

A macOS menu bar app that tracks your [Claude Code](https://claude.ai/code) token usage and costs — without leaving your desktop.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## Features

- **4 time dimensions** — switch between daily, weekly, monthly, and yearly views
- **Cost tracking** — total USD spent per period with delta vs. previous period
- **Token breakdown** — input, output, cache read, and cache write tokens
- **Model breakdown** — per-model usage and cost with proportional bars
- **7-day bar chart** — stacked input/output chart with current period highlighted
- **Cache savings** — estimated cost saved by prompt caching, calculated per model
- **Session stats** — number of sessions, projects, and active time span
- **Auto-refresh** — data reloads every 5 minutes in the background
- **Zero dependencies** — reads local JSONL files directly, no network required

---

## Screenshots

> Coming soon — contributions welcome!

---

## Installation

### Option 1: Download DMG (recommended)

1. Go to [Releases](../../releases/latest)
2. Download `ClaudeUsage-vX.X.X.dmg`
3. Open the DMG and drag **ClaudeUsage** to your **Applications** folder
4. Double-click to launch

> **First launch on macOS:** Apple will block apps from unidentified developers by default.
> To open ClaudeUsage:
> 1. **Right-click** (or Control-click) the app icon
> 2. Select **Open**
> 3. Click **Open** in the dialog that appears
>
> You only need to do this once.

### Option 2: Download ZIP

1. Go to [Releases](../../releases/latest)
2. Download `ClaudeUsage-vX.X.X.app.zip`
3. Unzip and move `ClaudeUsage.app` anywhere you like
4. Follow the same first-launch steps above

### Option 3: Build from Source

Requirements: **Xcode 15+** and **xcodegen** (`brew install xcodegen`)

```bash
git clone https://github.com/your-username/claude-code-usage.git
cd claude-code-usage
xcodegen generate
open ClaudeUsage.xcodeproj
```

Then press `⌘R` in Xcode to build and run.

---

## How It Works

ClaudeUsage reads the same local files that Claude Code writes during every session — no API calls, no account login required.

### Data source

Claude Code stores usage records as JSONL files on your Mac:

```
~/.claude/projects/**/*.jsonl          # default path
~/.config/claude/projects/**/*.jsonl   # XDG path
$CLAUDE_CONFIG_DIR/**/*.jsonl          # custom path (if set)
```

Each line is a JSON record containing:

```json
{
  "timestamp": "2026-04-07T10:30:00Z",
  "sessionId": "abc123",
  "message": {
    "model": "claude-opus-4-20250514",
    "usage": {
      "input_tokens": 1200,
      "output_tokens": 340,
      "cache_creation_input_tokens": 800,
      "cache_read_input_tokens": 2400
    }
  },
  "costUSD": 0.0124
}
```

### Processing pipeline

1. **Discover** — scan all three paths for `*.jsonl` files
2. **Parse** — decode each line, skip malformed entries and internal synthetic messages
3. **Deduplicate** — drop duplicate records using `message.id + requestId` as key
4. **Aggregate** — group entries by time period (day / week / month / year)
5. **Cost** — use the pre-calculated `costUSD` field when available; fall back to a built-in pricing table for older entries
6. **Render** — update the SwiftUI popover panel

### Architecture

```
ClaudeUsageApp          ← @main entry point, AppDelegate
StatusBarController     ← NSStatusItem + NSPopover lifecycle
UsageDataService        ← ObservableObject, 5-min Timer, aggregation
  ├── ClaudePathResolver   resolves all JSONL file paths
  ├── JSONLParser          parses + deduplicates entries
  └── CostCalculator       cost from costUSD or pricing table
Views/
  ├── UsagePopoverView     root panel (320pt wide)
  ├── DimensionTabBar      日 / 周 / 月 / 年 tabs
  ├── SummaryCardsRow      cost · tokens · cache rate cards
  ├── BarChartView         stacked bar chart
  ├── TokenBreakdownGrid   input / output / cache breakdown
  ├── ModelBreakdownList   per-model cost rows
  ├── SessionsInfoRow      sessions · projects · span
  └── FooterTotalRow       period total
```

---

## Usage

1. Launch **ClaudeUsage** — a bar chart icon (▪︎) appears in your menu bar
2. Click the icon to open the usage panel
3. Use the **日 / 周 / 月 / 年** tabs to switch time dimensions
4. Click anywhere outside the panel to close it

The panel refreshes automatically every 5 minutes. The timestamp in the top-right corner shows when data was last loaded.

---

## Supported Models

Built-in pricing table covers:

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| claude-opus-4 | $15 / 1M | $75 / 1M | $18.75 / 1M | $1.50 / 1M |
| claude-sonnet-4 | $3 / 1M | $15 / 1M | $3.75 / 1M | $0.30 / 1M |
| claude-haiku-4-5 | $0.80 / 1M | $4 / 1M | $1 / 1M | $0.08 / 1M |
| claude-haiku-3-5 | $0.80 / 1M | $4 / 1M | $1 / 1M | $0.08 / 1M |

Unknown models fall back to Sonnet pricing. When a `costUSD` field is present in the JSONL record, it is always used as-is.

---

## Requirements

- macOS 13.0 Ventura or later
- Claude Code installed and used at least once (so local data files exist)

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

To add support for a new model's pricing, edit `ClaudeUsage/Services/CostCalculator.swift`.

---

## License

MIT
