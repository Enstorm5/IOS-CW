import SwiftUI

enum AuraButtonKind {
    case primary
    case highlight
    case outline
}

struct AuraButtonStyle: ButtonStyle {
    var kind: AuraButtonKind = .primary
    var onNight = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let hasEdge = kind != .outline
        return configuration.label
            .font(.auraButton)
            .frame(maxWidth: .infinity, minHeight: AuraSize.control)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: AuraRadius.control))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: AuraRadius.control).strokeBorder(foreground, lineWidth: 3)
                }
            }
            .offset(y: pressed && hasEdge ? AuraSize.buttonEdge : 0)
            // Chunky game edge
            .background(alignment: .top) {
                if hasEdge {
                    RoundedRectangle(cornerRadius: AuraRadius.control)
                        .fill(edge)
                        .offset(y: AuraSize.buttonEdge)
                }
            }
            .padding(.bottom, hasEdge ? AuraSize.buttonEdge : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(pressed ? AuraMotion.pressedScale : 1)
            .animation(AuraMotion.bounce, value: pressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: pressed) { _, isDown in isDown }
    }

    private var edge: Color {
        kind == .highlight ? .auraYellowEdge : .auraMuted
    }

    private var foreground: Color {
        switch kind {
        case .primary: .auraBackground
        case .highlight: .auraInk
        case .outline: onNight ? .white : .auraText
        }
    }

    private var background: Color {
        switch kind {
        case .primary: .auraText
        case .highlight: .auraYellow
        case .outline: .clear
        }
    }
}

struct AuraTextField: View {
    let title: String
    @Binding var text: String
    var error: String? = nil
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .foregroundStyle(Color.auraText)
            .padding(.horizontal, AuraSpacing.control)
            .frame(minHeight: AuraSize.control)
            .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AuraRadius.control)
                    .strokeBorder(error == nil ? Color.clear : Color.auraError, lineWidth: 2)
            }

            if let error {
                ErrorMessage(text: error)
            }
        }
    }
}

struct ErrorMessage: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.auraErrorText)
            .foregroundStyle(Color.auraError)
    }
}

struct ChipToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.xSmall) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .font(isSelected ? .auraChipSelected : .auraChip)
            .foregroundStyle(isSelected ? Color.auraInk : Color.auraText)
            .padding(.horizontal, AuraSpacing.control)
            .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
            .background(isSelected ? Color.auraYellow : Color.auraChipOff, in: .capsule)
        }
        .buttonStyle(AuraBounceButtonStyle())
        .animation(AuraMotion.bounce, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AuraLogo: View {
    var size: CGFloat = AuraSize.logo
    var font: Font = .auraLogo
    var cornerRadius: CGFloat = AuraRadius.logo

    var body: some View {
        Text("A")
            .font(font)
            .foregroundStyle(Color.auraInk)
            .frame(width: size, height: size)
            .background(
                AngularGradient(colors: [.auraYellow, .auraMagenta, .auraMint, .auraYellow], center: .center),
                in: .rect(cornerRadius: cornerRadius)
            )
            .accessibilityHidden(true)
    }
}

struct AuraNightBackground: View {
    var body: some View {
        LinearGradient(colors: [.auraNightTop, .auraNightBottom], startPoint: .topLeading, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

// Avatar circle
struct AvatarView: View {
    let preset: AvatarPreset
    var size: CGFloat = 60

    var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(ring, lineWidth: size / 15))
            .accessibilityLabel(Text("\(preset.title) avatar"))
    }

    private var fill: Color {
        switch preset {
        case .magenta: .auraMagenta
        case .mint: .auraMint
        case .sunny: .auraYellow
        case .night: .auraInk
        }
    }

    private var ring: Color {
        switch preset {
        case .magenta: .auraYellow
        case .mint: .auraMagenta
        case .sunny: .auraMint
        case .night: .auraYellow
        }
    }
}

struct AuraPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.auraLink)
            .foregroundStyle(Color.auraBackground)
            .padding(.horizontal, AuraSpacing.large)
            .frame(minHeight: AuraSize.minTap)
            .background(Color.auraText, in: .capsule)
            .scaleEffect(configuration.isPressed ? AuraMotion.pressedScale : 1)
            .animation(AuraMotion.bounce, value: configuration.isPressed)
    }
}

struct StatusBanner: View {
    let systemImage: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: AuraSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.auraText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(message)
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraText)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.auraLink)
                        .foregroundStyle(Color.auraText)
                        .underline()
                        .frame(minHeight: AuraSize.minTap)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.control))
        .padding(.horizontal, AuraSpacing.screen)
    }
}

struct AuraPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.auraPill)
            .foregroundStyle(Color.auraInk)
            .padding(.horizontal, AuraSpacing.medium)
            .padding(.vertical, AuraSpacing.xSmall)
            .background(Color.auraYellow, in: .capsule)
            .contentTransition(.numericText())
            .animation(AuraMotion.bounce, value: text)
    }
}

struct AuraBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AuraMotion.pressedScale : 1)
            .animation(AuraMotion.bounce, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, isDown in isDown }
    }
}

// Cards pop in
private struct AuraPopIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(hasAppeared || reduceMotion ? 1 : AuraMotion.popStartScale)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                withAnimation(AuraMotion.pop) { hasAppeared = true }
            }
            .onDisappear {
                hasAppeared = false
            }
    }
}

extension View {
    func auraPopIn() -> some View {
        modifier(AuraPopIn())
    }
}
