# Claude Code Usage — macOS 菜单栏 App 设计文档

**日期**: 2026-04-06  
**状态**: 已批准  

---

## 1. 概述

一个 macOS 菜单栏原生应用，读取 Claude Code 本地 JSONL 数据文件，以日/周/月/年四个维度展示 token 用量和花费统计。使用 Swift + SwiftUI 构建，UI 风格参考 Supabase 设计系统（深色科技风，绿色 #3ecf8e 为主色）。

---

## 2. 技术栈

- **语言/框架**: Swift 5.9+，SwiftUI
- **macOS 最低版本**: macOS 13 Ventura
- **核心 API**:
  - `NSStatusItem` — 菜单栏图标
  - `NSPopover` — 点击弹出的自定义面板
  - `Timer` — 定时刷新数据（每 5 分钟）
- **数据解析**: 纯 Swift，无第三方依赖
- **打包**: 标准 `.app` bundle，支持直接双击运行

---

## 3. 数据来源

### 3.1 文件路径

按优先级依次查找：
1. 环境变量 `CLAUDE_CONFIG_DIR`（逗号分隔多路径）
2. `~/.config/claude/projects/`（XDG 标准路径）
3. `~/.claude/projects/`（旧版默认路径）

Glob 模式：`**/*.jsonl`，递归扫描所有子目录。

### 3.2 JSONL 数据格式

每行一个 JSON 对象，关键字段：

```json
{
  "timestamp": "2026-04-06T10:30:00Z",
  "sessionId": "abc123",
  "message": {
    "id": "msg_xyz",
    "model": "claude-opus-4-20250514",
    "usage": {
      "input_tokens": 1200,
      "output_tokens": 340,
      "cache_creation_input_tokens": 800,
      "cache_read_input_tokens": 2400
    }
  },
  "costUSD": 0.0124,
  "requestId": "req_abc"
}
```

### 3.3 去重规则

使用 `message.id + requestId` 组合作为去重 key，跳过重复条目（与 ccusage 一致）。跳过 `isApiErrorMessage: true` 的条目。

### 3.4 成本计算

优先使用 `costUSD` 字段（预计算值）。若该字段缺失，则根据模型名称和 token 数量按 Anthropic 公开定价计算，内置常用模型的定价表（硬编码，不依赖网络）。

---

## 4. 数据聚合

### 4.1 时区

使用系统本地时区进行日期分组。

### 4.2 四个维度的聚合逻辑

| 维度 | 分组 key | 柱状图范围 |
|------|----------|-----------|
| 日   | `YYYY-MM-DD`（今日） | 近 7 日 |
| 周   | 本自然周（周一为起始） | 近 8 周 |
| 月   | `YYYY-MM`（本月） | 近 12 月 |
| 年   | `YYYY`（本年） | 近 5 年 |

### 4.3 每个维度输出的指标

**摘要层**：
- `totalCostUSD` — 当前周期总花费
- `totalTokens` — 四类 token 之和
- `cacheHitRate` — `cacheReadTokens / totalTokens`（缓存命中率）
- `costDelta` — 与上一个同等周期的花费差值（用于趋势箭头）
- `tokenDelta` — 与上一个同等周期的 token 变化百分比

**Token 明细**：
- `inputTokens`
- `outputTokens`
- `cacheReadTokens`
- `cacheCreationTokens`

**模型明细**（按花费降序）：
- `modelName`
- `totalTokens`（该模型）
- `costUSD`（该模型）
- `costRatio`（占总花费百分比，用于渲染进度条）

**Sessions 信息**：
- `sessionCount` — 当前周期内的唯一 sessionId 数量
- `projectCount` — 当前周期内的唯一 `cwd`（项目路径）数量
- `activeDuration` — 最早到最晚 timestamp 的跨度（近似活跃时长）

---

## 5. 应用架构

```
ClaudeUsageApp (App)
├── AppDelegate / StatusBarController
│   ├── NSStatusItem（菜单栏图标）
│   └── NSPopover → UsagePopoverView (SwiftUI)
│
├── UsageDataService（数据层，ObservableObject）
│   ├── loadData() — 扫描并解析所有 JSONL 文件
│   ├── aggregate(for: TimeDimension) → AggregatedStats
│   └── Timer（每 5 分钟调用 loadData()）
│
├── Models
│   ├── UsageEntry（单条 JSONL 解析结果）
│   ├── AggregatedStats（聚合后的统计数据）
│   ├── ModelBreakdown（单模型明细）
│   └── TimeDimension（enum: day / week / month / year）
│
└── Views (SwiftUI)
    ├── UsagePopoverView（面板根视图，持有 selectedDimension）
    ├── DimensionTabBar（日/周/月/年 Tab）
    ├── SummaryCardsRow（3 张摘要卡片）
    ├── BarChartView（近 N 期堆叠柱状图）
    ├── TokenBreakdownGrid（2×2 Token 明细）
    ├── ModelBreakdownList（模型明细列表）
    ├── SessionsInfoRow（会话/项目/时长）
    └── FooterTotalRow（底部合计）
```

---

## 6. UI 设计规范

### 6.1 面板尺寸

- 宽度：**320pt**（固定）
- 高度：自适应内容，约 480–520pt

### 6.2 配色（Supabase 深色系）

| 用途 | 颜色 |
|------|------|
| 页面背景 | `#171717` |
| 卡片背景 | `#1e1e1e` |
| 边框（标准） | `#2e2e2e` |
| 边框（细分割线） | `#242424` |
| 主色（绿） | `#3ecf8e` |
| 主色发光 | `rgba(62,207,142,0.4)` |
| Input bar 色 | `#2a8c5e` |
| Output bar 色 | `#3ecf8e` |
| 文字主色 | `#fafafa` |
| 文字次色 | `#b4b4b4` |
| 文字弱色 | `#898989` |
| 文字极弱 | `#4d4d4d` |
| 上升趋势 | `#3ecf8e` |
| 下降趋势 | `#f87171` |

### 6.3 字体

- UI 文字：SF Pro（系统默认）
- 模型名称：SF Mono（等宽）
- 数字：`monospacedDigit` 修饰符（对齐）

### 6.4 各区域布局

**Header**（13pt）：左侧绿色脉冲点 + "Claude Usage"，右侧刷新时间  
**Tab 栏**（11pt）：日/周/月/年，激活项绿色下划线  
**摘要卡片**（3列等宽）：标签 9pt 大写 + 数值 16pt + 趋势 10pt  
**柱状图**（高度 52pt）：Input/Output 堆叠，今日/本期高亮发光  
**Token 明细**（2×2 网格）：彩色圆点 + 名称 + 数值，10pt  
**模型明细**：模型名（SF Mono 10pt）+ token 数 + 进度条（36pt宽）+ 花费（绿色 11pt）  
**Sessions 行**：图标 + 标签 + 数值，三项横排，10pt  
**底部合计**：左侧标签+token总量，右侧花费 14pt 粗体绿色  

### 6.5 菜单栏图标

使用 SF Symbol `cpu` 或自定义模板图（黑白，16×16pt），不显示文字。

---

## 7. 刷新策略

- 应用启动时立即加载一次数据
- 之后每 **5 分钟**自动刷新（`Timer.scheduledTimer`）
- 面板打开时若距上次刷新超过 5 分钟，触发一次即时刷新
- 刷新时间显示在 Header 右侧（"5m ago" 格式）

---

## 8. 错误处理

- 若 Claude 数据目录不存在：面板显示提示文字 "未找到 Claude Code 数据，请确认已安装并使用过 Claude Code"
- 若 JSONL 文件解析失败（单行）：跳过该行，继续解析
- 无网络依赖，所有计算本地完成

---

## 9. 分发方式

目标：其他用户可从 GitHub 下载后直接使用，无需安装 Xcode 或配置开发环境。

### 9.1 分发产物

提供两种方式，同时支持：

| 方式 | 适用人群 | 说明 |
|------|----------|------|
| **DMG 安装包** | 普通用户 | 下载 `.dmg`，拖入 Applications，双击启动 |
| **GitHub Releases zip** | 开发者 | 下载 `.app.zip`，解压后直接运行 |

### 9.2 代码签名策略

由于没有付费 Apple Developer 账号（$99/年），采用**自签名（ad-hoc）**方式：

```bash
codesign --deep --force --sign - ClaudeUsage.app
```

用户首次运行需要：右键 → 打开 → 确认（绕过 Gatekeeper 一次）。在 README 中提供截图说明。

若后续有 Developer ID，可升级为正式签名，用户体验更流畅。

### 9.3 构建与发布流程（GitHub Actions）

在 `.github/workflows/release.yml` 中配置自动化构建：

1. 触发条件：推送 `v*` tag（如 `v1.0.0`）
2. 构建步骤：
   - `xcodebuild archive` → 生成 `.xcarchive`
   - `xcodebuild -exportArchive` → 导出 `.app`
   - `codesign --sign -` → ad-hoc 签名
   - 打包为 `.dmg`（使用 `create-dmg` 工具）和 `.app.zip`
3. 自动创建 GitHub Release，上传两个产物

### 9.4 项目结构要求

- 使用 **Swift Package Manager**（不依赖 CocoaPods/Carthage），方便他人 clone 后直接用 Xcode 打开
- 无第三方依赖，纯系统 API
- `README.md` 包含：安装说明、截图、"首次运行如何绕过 Gatekeeper" 说明

---

## 10. 不在本期范围内

- 通知/提醒功能
- 用量阈值告警
- 数据导出
- 多账号支持
- Sparkline 折线图（仅做堆叠柱状图）
- 设置页面（刷新间隔、时区等可配置项）
- Mac App Store 上架（需付费开发者账号）
