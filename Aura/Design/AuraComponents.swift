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
        configuration.label
            .font(.auraButton)
            .frame(maxWidth: .infinity, minHeight: AuraSize.control)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: AuraRadius.control))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: AuraRadius.control).strokeBorder(foreground, lineWidth: 2)
                }
            }
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
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
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AuraLogo: View {
    var body: some View {
        Text("A")
            .font(.auraLogo)
            .foregroundStyle(Color.auraInk)
            .frame(width: 76, height: 76)
            .background(
                AngularGradient(colors: [.auraYellow, .auraMagenta, .auraMint, .auraYellow], center: .center),
                in: .rect(cornerRadius: AuraRadius.logo)
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
