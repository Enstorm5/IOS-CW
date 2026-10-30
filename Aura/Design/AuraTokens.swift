import SwiftUI
import CoreText

// Load font file
nonisolated func registerAuraFonts() {
    guard let url = Bundle.main.url(forResource: "BricolageGrotesque", withExtension: "ttf") else { return }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

private func bricolage(_ weight: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
    .custom("BricolageGrotesque-96ptExtraBold_\(weight)", size: size, relativeTo: style)
}

// Text styles
extension Font {
    static let auraScreenTitle = bricolage("ExtraBold", size: 34, relativeTo: .largeTitle)
    static let auraHeading = bricolage("ExtraBold", size: 28, relativeTo: .title)
    static let auraButton = bricolage("ExtraBold", size: 17, relativeTo: .headline)
    static let auraCardTitle = bricolage("ExtraBold", size: 17, relativeTo: .headline)
    static let auraLink = bricolage("Bold", size: 15, relativeTo: .subheadline)
    static let auraSectionLabel = bricolage("Bold", size: 15, relativeTo: .subheadline)
    static let auraNotice = bricolage("SemiBold", size: 15, relativeTo: .subheadline)
    static let auraChip = bricolage("SemiBold", size: 15, relativeTo: .subheadline)
    static let auraChipSelected = bricolage("ExtraBold", size: 15, relativeTo: .subheadline)
    static let auraPill = bricolage("ExtraBold", size: 13, relativeTo: .footnote)
    static let auraErrorText = bricolage("SemiBold", size: 13, relativeTo: .footnote)
    static let auraIcon = Font.largeTitle
    static let auraLogo = Font.system(size: 34, weight: .heavy)
    static let auraPinIcon = Font.caption2.weight(.heavy)
}

// Spacing tokens
enum AuraSpacing {
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 6
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let control: CGFloat = 14
    static let large: CGFloat = 16
    static let screen: CGFloat = 20
    static let xLarge: CGFloat = 24
}

// Corner radii
enum AuraRadius {
    static let control: CGFloat = 12
    static let swatch: CGFloat = 10
    static let row: CGFloat = 14
    static let card: CGFloat = 18
    static let logo: CGFloat = 24
}

// Size tokens
enum AuraSize {
    static let control: CGFloat = 50
    static let minTap: CGFloat = 44
    static let pin: CGFloat = 30
    static let pinBorder: CGFloat = 3
    static let messageSwatch: CGFloat = 32
    static let teaserBlur: CGFloat = 6
    static let messageEditorHeight: CGFloat = 110
    static let drawingThumbnailHeight: CGFloat = 90
    static let drawingTexturePixelWidth: CGFloat = 640
    static let badgeTileHeight: CGFloat = 96
    static let profileAvatar: CGFloat = 88
    static let avatarChoice: CGFloat = 56
}
