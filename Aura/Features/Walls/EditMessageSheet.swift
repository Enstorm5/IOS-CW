import SwiftUI

struct EditMessageSheet: View {
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(originalText: String, onSave: @escaping (String) async throws -> Void) {
        self.onSave = onSave
        _text = State(initialValue: originalText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Color.auraText)
                    .frame(minHeight: AuraSize.messageEditorHeight)
                    .padding(AuraSpacing.small)
                    .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.control))
                    .accessibilityLabel("Message")

                Text(characterCountText(text))
                    .font(.auraErrorText)
                    .foregroundStyle(isOverMessageLength(text) ? Color.auraError : Color.auraMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                if let errorMessage {
                    ErrorMessage(text: errorMessage)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(isSaving)

                Spacer()
            }
            .padding(AuraSpacing.screen)
            .background(Color.auraBackground)
            .navigationTitle("Edit message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
        }
        .tint(Color.auraText)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        errorMessage = nil
        if let validationError = messageValidationError(text) {
            errorMessage = validationError
            return
        }
        isSaving = true
        do {
            try await onSave(text)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
