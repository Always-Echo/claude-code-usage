# ClaudeUsage

**English** | [中文](#中文)

A macOS menu bar app that tracks your [Claude Code](https://claude.ai/code) token usage and costs — without leaving your desktop.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)

---

## Features

- **4 time dimensions** — daily, weekly, monthly, and yearly views
- **Cost tracking** — total USD spent with delta vs. previous period
- **Token breakdown** — input, output, cache read, and cache write
- **Model breakdown** — per-model usage and cost with proportional bars
- **Bar chart** — stacked input/output chart with current period highlighted
- **Cache savings** — estimated savings from prompt caching, per model
- **Auto-refresh** — reloads every 5 minutes, zero network required

---

## Installation

### Option 1: DMG (recommended)

1. Download `ClaudeUsage-vX.X.X.dmg` from [Releases](../../releases/latest)
2. Open the DMG and drag **ClaudeUsage** to **Applications**
3. Launch the app

> **First launch:** macOS will block unidentified apps by default.
> Right-click the app → **Open** → **Open**. You only need to do this once.

### Option 2: ZIP

Download `ClaudeUsage-vX.X.X.app.zip` from [Releases](../../releases/latest), unzip, and run. Same first-launch step applies.

### Option 3: Build from Source

Requires **Xcode 16+** and **xcodegen** (`brew install xcodegen`).

```bash
git clone https://github.com/Always-Echo/claude-code-usage.git
cd claude-code-usage
xcodegen generate
open ClaudeUsage.xcodeproj
```

Press `⌘R` in Xcode to build and run.

---

## How It Works

ClaudeUsage reads the JSONL files Claude Code writes locally — no API calls, no login.

**Data paths scanned:**
```
~/.claude/projects/**/*.jsonl
~/.config/claude/projects/**/*.jsonl
$CLAUDE_CONFIG_DIR/**/*.jsonl
```

**Pipeline:** Discover → Parse → Deduplicate → Aggregate → Render

Cost uses the `costUSD` field when present; otherwise falls back to a built-in pricing table (supports fast-mode 5× multiplier).

**Architecture:**
```
StatusBarController     NSStatusItem + NSPopover
UsageDataService        aggregation, 5-min timer
  ├── ClaudePathResolver
  ├── JSONLParser
  └── CostCalculator
Views/
  ├── UsagePopoverView  320pt panel
  ├── DimensionTabBar   日/周/月/年
  ├── SummaryCardsRow   cost · tokens · cache rate
  ├── BarChartView      stacked bar chart
  ├── TokenBreakdownGrid
  ├── ModelBreakdownList
  ├── SessionsInfoRow
  └── FooterTotalRow
```

---

## Supported Models

| Model | Input | Output | Cache Write | Cache Read |
|-------|-------|--------|-------------|------------|
| claude-opus-4 | $15/1M | $75/1M | $18.75/1M | $1.50/1M |
| claude-sonnet-4 | $3/1M | $15/1M | $3.75/1M | $0.30/1M |
| claude-haiku-4-5 / 3-5 | $0.80/1M | $4/1M | $1/1M | $0.08/1M |

Unknown models fall back to Sonnet pricing. Fast mode applies a 5× multiplier.

---

## Requirements

- macOS 13.0 Ventura or later
- Claude Code installed and used at least once

---

## Contributing

PRs welcome. To add a new model's pricing, edit `ClaudeUsage/Services/CostCalculator.swift`.

---

## License

MIT

---

<a name="中文"></a>

# ClaudeUsage

[English](#) | **中文**

一款 macOS 菜单栏应用，实时追踪 [Claude Code](https://claude.ai/code) 的 token 用量与费用，无需离开桌面。

---

## 功能特性

- **4 个时间维度** — 日、周、月、年视图自由切换
- **费用追踪** — 当前周期总花费及与上一周期的对比
- **Token 明细** — Input、Output、Cache Read、Cache Write 分类展示
- **模型明细** — 各模型用量与费用，附比例进度条
- **柱状图** — Input/Output 堆叠图，当前周期高亮显示
- **缓存节省** — 按模型精确计算 Prompt Cache 节省的费用
- **自动刷新** — 每 5 分钟后台刷新，无需网络

---

## 安装方式

### 方式一：DMG 安装包（推荐）

1. 从 [Releases](../../releases/latest) 下载 `ClaudeUsage-vX.X.X.dmg`
2. 打开 DMG，将 **ClaudeUsage** 拖入 **Applications（应用程序）**文件夹
3. 双击启动

> **首次启动提示：** macOS 会拦截未经认证的应用。
> 右键点击应用图标 → **打开** → **打开**，仅需操作一次。

### 方式二：ZIP 压缩包

从 [Releases](../../releases/latest) 下载 `ClaudeUsage-vX.X.X.app.zip`，解压后直接运行，首次启动同上。

### 方式三：从源码构建

需要 **Xcode 16+** 和 **xcodegen**（`brew install xcodegen`）。

```bash
git clone https://github.com/Always-Echo/claude-code-usage.git
cd claude-code-usage
xcodegen generate
open ClaudeUsage.xcodeproj
```

在 Xcode 中按 `⌘R` 构建运行。

---

## 实现原理

ClaudeUsage 直接读取 Claude Code 在本地写入的 JSONL 文件，无需 API 调用，无需登录账号。

**数据路径：**
```
~/.claude/projects/**/*.jsonl
~/.config/claude/projects/**/*.jsonl
$CLAUDE_CONFIG_DIR/**/*.jsonl
```

**处理流程：** 发现文件 → 解析 → 去重 → 按时间聚合 → 渲染

费用计算优先使用记录中的 `costUSD` 字段；若缺失则使用内置定价表（支持 Fast 模式 5 倍费率）。

---

## 支持的模型

| 模型 | Input | Output | Cache Write | Cache Read |
|------|-------|--------|-------------|------------|
| claude-opus-4 | $15/1M | $75/1M | $18.75/1M | $1.50/1M |
| claude-sonnet-4 | $3/1M | $15/1M | $3.75/1M | $0.30/1M |
| claude-haiku-4-5 / 3-5 | $0.80/1M | $4/1M | $1/1M | $0.08/1M |

未知模型默认使用 Sonnet 定价，Fast 模式乘以 5 倍费率。

---

## 系统要求

- macOS 13.0 Ventura 及以上
- 已安装 Claude Code 并至少使用过一次（本地需有数据文件）

---

## 参与贡献

欢迎提交 PR。如需新增模型定价，修改 `ClaudeUsage/Services/CostCalculator.swift` 即可。

---

## 许可证

MIT
