import SwiftUI

let messageNudgeStep = 0.05
let textCardHeightFraction = 0.35

// Move on wall
struct MoveMessageSheet: View {
    let wallSize: WallSize
    let messages: [WallMessage]
    let moving: WallMessage
    let onSave: ((x: Double, y: Double)) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: CGPoint
    @State private var dragStart: CGPoint?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(wallSize: WallSize, messages: [WallMessage], moving: WallMessage, onSave: @escaping ((x: Double, y: Double)) async throws -> Void) {
        self.wallSize = wallSize
        self.messages = messages
        self.moving = moving
        self.onSave = onSave
        _position = State(initialValue: CGPoint(x: moving.normalizedX, y: moving.normalizedY))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    Text("Drag your message to a new spot. This is a flat view of the wall.")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraMuted)

                    wallCanvas

                    nudgeButtons

                    if let errorMessage {
                        ErrorMessage(text: errorMessage)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Color.auraInk)
                        } else {
                            Text("Save position")
                        }
                    }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                    .disabled(isSaving)
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .navigationTitle("Move on wall")
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

    private var wallCanvas: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Rectangle()
                    .fill(Color.auraLilac)

                ForEach(messages.filter { $0.id != moving.id }) { message in
                    card(for: message, canvas: size)
                        .opacity(0.55)
                        .position(x: message.normalizedX * size.width, y: message.normalizedY * size.height)
                }

                card(for: moving, canvas: size)
                    .overlay {
                        RoundedRectangle(cornerRadius: AuraRadius.swatch)
                            .strokeBorder(Color.auraInk, lineWidth: AuraSize.pinBorder)
                    }
                    .position(x: position.x * size.width, y: position.y * size.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let start = dragStart ?? position
                                dragStart = start
                                let moved = movedPlacement(start: (Double(start.x), Double(start.y)), translation: value.translation, canvas: size)
                                position = CGPoint(x: moved.x, y: moved.y)
                            }
                            .onEnded { _ in dragStart = nil }
                    )
                    .accessibilityLabel("Your message. Use the arrow buttons to move it.")
            }
            .clipShape(.rect(cornerRadius: AuraRadius.control))
        }
        .aspectRatio(wallSize.width / wallSize.height, contentMode: .fit)
    }

    @ViewBuilder
    private func card(for message: WallMessage, canvas: CGSize) -> some View {
        let width = canvas.width * messageCardWidthFraction
        if message.contentType == .drawing, let drawing = message.drawing {
            DrawingView(drawing: drawing)
                .frame(width: width, height: width / drawingAspectRatio)
                .clipShape(.rect(cornerRadius: AuraRadius.swatch))
        } else {
            Text(message.text)
                .font(.auraErrorText)
                .foregroundStyle(message.color == .ink ? Color.white : Color.auraInk)
                .lineLimit(2)
                .padding(AuraSpacing.xSmall)
                .frame(width: width, height: width * textCardHeightFraction)
                .background(message.color.swatchColor, in: .rect(cornerRadius: AuraRadius.swatch))
        }
    }

    private var nudgeButtons: some View {
        HStack(spacing: AuraSpacing.small) {
            nudgeButton("arrow.left", label: "Move left", dx: -messageNudgeStep, dy: 0)
            nudgeButton("arrow.up", label: "Move up", dx: 0, dy: -messageNudgeStep)
            nudgeButton("arrow.down", label: "Move down", dx: 0, dy: messageNudgeStep)
            nudgeButton("arrow.right", label: "Move right", dx: messageNudgeStep, dy: 0)
        }
    }

    private func nudgeButton(_ systemImage: String, label: String, dx: Double, dy: Double) -> some View {
        Button {
            position = CGPoint(x: clampedPlacement(Double(position.x) + dx), y: clampedPlacement(Double(position.y) + dy))
        } label: {
            Image(systemName: systemImage)
                .frame(maxWidth: .infinity, minHeight: AuraSize.minTap)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        do {
            try await onSave((clampedPlacement(Double(position.x)), clampedPlacement(Double(position.y))))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
