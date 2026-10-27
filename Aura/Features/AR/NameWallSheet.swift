import SwiftUI

struct NameWallSheet: View {
    let isPublishing: Bool
    let costMessage: String
    let errorMessage: String?
    let onPublish: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var showFieldErrors = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    AuraTextField(title: "Wall name", text: $title, error: showFieldErrors ? wallTitleValidationError(title) : nil)

                    Text("The wall appears on the map at your current location. Anyone signed in can find it, and people within 50 m can read and write on it.")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraMuted)

                    Label(costMessage, systemImage: "sparkles")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraText)

                    if let errorMessage {
                        ErrorMessage(text: errorMessage)
                    }

                    Button {
                        showFieldErrors = true
                        if wallTitleValidationError(title) == nil {
                            onPublish(title)
                        }
                    } label: {
                        if isPublishing {
                            ProgressView().tint(Color.auraInk)
                        } else {
                            Text("Publish")
                        }
                    }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                    .disabled(isPublishing)
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .navigationTitle("Name your wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isPublishing)
                }
            }
        }
        .tint(Color.auraText)
        .interactiveDismissDisabled(isPublishing)
    }
}
