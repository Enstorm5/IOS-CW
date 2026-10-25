import SwiftUI

struct WriteMessageView: View {
    let onPost: (String, MessageColor) async throws -> Void
    let onSaveDraft: (String, MessageColor) -> Void
    let onDiscardDraft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var color: MessageColor
    @State private var isPosting = false
    @State private var didPost = false
    @State private var restoredDraft: Bool
    @State private var errorMessage: String?
    @FocusState private var isEditorFocused: Bool

    init(
        initialDraft: MessageDraft?,
        onPost: @escaping (String, MessageColor) async throws -> Void,
        onSaveDraft: @escaping (String, MessageColor) -> Void,
        onDiscardDraft: @escaping () -> Void
    ) {
        self.onPost = onPost
        self.onSaveDraft = onSaveDraft
        self.onDiscardDraft = onDiscardDraft
        _text = State(initialValue: initialDraft?.text ?? "")
        _color = State(initialValue: initialDraft?.color ?? .magenta)
        _restoredDraft = State(initialValue: initialDraft != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    if restoredDraft {
                        HStack {
                            AuraPill(text: "Draft restored")
                            Spacer()
                            Button("Discard draft") {
                                text = ""
                                restoredDraft = false
                                onDiscardDraft()
                            }
                            .font(.auraLink)
                            .foregroundStyle(Color.auraText)
                            .frame(minHeight: AuraSize.minTap)
                        }
                    }

                    editor

                    Text(characterCountText(text))
                        .font(.auraErrorText)
                        .foregroundStyle(isOverMessageLength(text) ? Color.auraError : Color.auraMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    Text("Color")
                        .font(.auraSectionLabel)
                        .foregroundStyle(Color.auraMuted)

                    HStack(spacing: AuraSpacing.medium) {
                        ForEach(MessageColor.allCases, id: \.self) { option in
                            ColorSwatchButton(color: option, isSelected: option == color) {
                                color = option
                            }
                        }
                    }

                    if let errorMessage {
                        ErrorMessage(text: errorMessage)
                    }

                    Button {
                        Task { await post() }
                    } label: {
                        if isPosting {
                            ProgressView().tint(Color.auraInk)
                        } else {
                            Text("Post to wall")
                        }
                    }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                    .disabled(isPosting)
                    .padding(.top, AuraSpacing.small)
                }
                .padding(AuraSpacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.auraBackground)
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isPosting)
                }
            }
            .onAppear { isEditorFocused = true }
            .onDisappear {
                if !didPost {
                    onSaveDraft(text, color)
                }
            }
        }
        .tint(Color.auraText)
        .interactiveDismissDisabled(isPosting)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isEditorFocused)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Color.auraText)
                .frame(minHeight: AuraSize.messageEditorHeight)
                .padding(AuraSpacing.small)
                .accessibilityLabel("Message")

            if text.isEmpty {
                Text("Say something kind…")
                    .foregroundStyle(Color.auraMuted)
                    .padding(.horizontal, AuraSpacing.control)
                    .padding(.vertical, AuraSpacing.large)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.control))
    }

    private func post() async {
        errorMessage = nil
        if let validationError = messageValidationError(text) {
            errorMessage = validationError
            return
        }

        isPosting = true
        do {
            try await onPost(text, color)
            didPost = true
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPosting = false
    }
}

struct ColorSwatchButton: View {
    let color: MessageColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.swatchColor)
                .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.auraCardTitle)
                            .foregroundStyle(color == .ink ? Color.white : Color.auraInk)
                    }
                }
                .overlay {
                    Circle().strokeBorder(Color.auraText, lineWidth: isSelected ? AuraSize.pinBorder : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(color.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension MessageColor {
    var swatchColor: Color {
        switch self {
        case .magenta: .auraMagenta
        case .mint: .auraMint
        case .yellow: .auraYellow
        case .ink: .auraInk
        }
    }
}
