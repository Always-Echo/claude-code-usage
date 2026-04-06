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
