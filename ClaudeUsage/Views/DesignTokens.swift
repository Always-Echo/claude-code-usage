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
