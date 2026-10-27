import SwiftUI

extension Font {
    static let auraScreenTitle = Font.largeTitle.weight(.heavy)
    static let auraHeading = Font.title.weight(.heavy)
    static let auraButton = Font.headline.weight(.heavy)
    static let auraCardTitle = Font.headline.weight(.heavy)
    static let auraLink = Font.subheadline.weight(.bold)
    static let auraSectionLabel = Font.subheadline.weight(.bold)
    static let auraNotice = Font.subheadline.weight(.semibold)
    static let auraChip = Font.subheadline.weight(.semibold)
    static let auraChipSelected = Font.subheadline.weight(.heavy)
    static let auraPill = Font.footnote.weight(.heavy)
    static let auraErrorText = Font.footnote.weight(.semibold)
    static let auraIcon = Font.largeTitle
    static let auraLogo = Font.system(size: 34, weight: .heavy)
    static let auraPinIcon = Font.caption2.weight(.heavy)
}

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

enum AuraRadius {
    static let control: CGFloat = 12
    static let swatch: CGFloat = 10
    static let row: CGFloat = 14
    static let card: CGFloat = 18
    static let logo: CGFloat = 24
}

enum AuraSize {
    static let control: CGFloat = 50
    static let minTap: CGFloat = 44
    static let pin: CGFloat = 30
    static let pinBorder: CGFloat = 3
    static let messageSwatch: CGFloat = 32
    static let teaserBlur: CGFloat = 6
    static let messageEditorHeight: CGFloat = 110
    static let guidancePhotoWidth: CGFloat = 120
    static let drawingThumbnailHeight: CGFloat = 90
    static let drawingTexturePixelWidth: CGFloat = 640
    static let badgeTileHeight: CGFloat = 96
}
