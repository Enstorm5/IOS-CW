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
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(foreground)
            .background(background, in: .rect(cornerRadius: 12))
            .overlay {
                if kind == .outline {
                    RoundedRectangle(cornerRadius: 12).strokeBorder(foreground, lineWidth: 2)
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
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .foregroundStyle(Color.auraText)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.auraCard, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.auraError)
    }
}

struct ChipToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .font(.subheadline.weight(isSelected ? .heavy : .semibold))
            .foregroundStyle(isSelected ? Color.auraInk : Color.auraText)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Color.auraYellow : Color.auraChipOff, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AuraLogo: View {
    var body: some View {
        Text("A")
            .font(.system(size: 34, weight: .heavy))
            .foregroundStyle(Color.auraInk)
            .frame(width: 76, height: 76)
            .background(
                AngularGradient(colors: [.auraYellow, .auraMagenta, .auraMint, .auraYellow], center: .center),
                in: .rect(cornerRadius: 24)
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
