import SwiftUI
import UIKit

// Colour tokens
extension Color {
    static let auraBackground = Color(light: 0xF7F5FF, dark: 0x14112B)
    static let auraCard = Color(light: 0xFFFFFF, dark: 0x231F47)
    static let auraText = Color(light: 0x1E1A3C, dark: 0xF1EEFF)
    static let auraMuted = Color(light: 0x6B6690, dark: 0xA7A2D0)
    static let auraChipOff = Color(light: 0xE2DEF7, dark: 0x3A3470)
    static let auraError = Color(light: 0xC2185B, dark: 0xFF7AA8)

    static let auraInk = Color(uiColor: uiColor(hex: 0x1E1A3C))
    static let auraLilac = Color(uiColor: uiColor(hex: 0xEEEAFB))
    static let auraYellowEdge = Color(uiColor: uiColor(hex: 0xC99A12))
    static let auraYellow = Color(uiColor: uiColor(hex: 0xFFD84D))
    static let auraMint = Color(uiColor: uiColor(hex: 0x2FC9B8))
    static let auraMagenta = Color(uiColor: uiColor(hex: 0xFF4F8B))

    static let auraNightTop = Color(uiColor: uiColor(hex: 0x2B2560))
    static let auraNightBottom = Color(uiColor: uiColor(hex: 0x0E0C22))

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            uiColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

nonisolated func uiColor(hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}
