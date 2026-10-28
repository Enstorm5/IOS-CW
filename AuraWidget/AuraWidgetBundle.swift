import WidgetKit
import SwiftUI

@main
struct AuraWidgetBundle: WidgetBundle {
    init() {
        registerAuraFonts()
    }

    var body: some Widget {
        AuraWidget()
    }
}
