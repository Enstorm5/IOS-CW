import SwiftUI

struct MyWallsView: View {
    let publisher: WallPublishService
    let ownerID: String

    @State private var walls: [Wall] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var renamingWall: Wall?
    @State private var deletingWall: Wall?
    @State private var busyWallID: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.small) {
                if let errorMessage {
                    StatusBanner(systemImage: "exclamationmark.circle", message: errorMessage, actionTitle: "Retry") {
                        Task { await load() }
                    }
                }

                if isLoading && walls.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: AuraSize.control)
                } else if hasLoaded && walls.isEmpty && errorMessage == nil {
                    StatusBanner(systemImage: "square.dashed", message: "You haven't placed any walls yet. Use the Camera tab to place one.")
                }

                ForEach(walls) { wall in
                    MyWallRow(
                        wall: wall,
                        isBusy: busyWallID == wall.id,
                        onRename: { renamingWall = wall },
                        onDelete: { deletingWall = wall }
                    )
                }
            }
            .padding(.vertical, AuraSpacing.medium)
        }
        .background(Color.auraBackground)
        .navigationTitle("My walls")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasLoaded {
                await load()
            }
        }
        .refreshable { await load() }
        .sheet(item: $renamingWall) { wall in
            RenameWallSheet(originalTitle: wall.title) { newTitle in
                try await rename(wall, to: newTitle)
            }
        }
        .confirmationDialog(
            "Delete this wall?",
            isPresented: Binding(get: { deletingWall != nil }, set: { if !$0 { deletingWall = nil } }),
            titleVisibility: .visible,
            presenting: deletingWall
        ) { wall in
            Button("Delete wall", role: .destructive) {
                Task { await delete(wall) }
            }
        } message: { _ in
            Text("The wall and its map are removed for everyone, and its messages disappear with it. Points aren't refunded.")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            walls = try await publisher.fetchMyWalls(ownerID: ownerID)
            hasLoaded = true
        } catch {
            errorMessage = "Couldn't load your walls. Check your connection and try again."
        }
        isLoading = false
    }

    private func rename(_ wall: Wall, to newTitle: String) async throws {
        let cleaned = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if let titleError = wallTitleValidationError(cleaned) {
            throw UserFacingError(message: titleError)
        }
        do {
            try await publisher.renameWall(wallID: wall.id, title: cleaned)
        } catch {
            throw UserFacingError(message: "Couldn't rename the wall. Check your connection and try again.")
        }
        walls = renamedWalls(walls, wallID: wall.id, title: cleaned)
    }

    private func delete(_ wall: Wall) async {
        busyWallID = wall.id
        errorMessage = nil
        do {
            try await publisher.deleteWall(wallID: wall.id)
            walls.removeAll { $0.id == wall.id }
        } catch {
            errorMessage = "Couldn't delete the wall. Check your connection and try again."
        }
        busyWallID = nil
    }
}

private struct MyWallRow: View {
    let wall: Wall
    let isBusy: Bool
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            Image(systemName: "square.on.square.dashed")
                .foregroundStyle(Color.auraInk)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                .background(Color.auraMint, in: .rect(cornerRadius: AuraRadius.swatch))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(wall.title)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text(myWallDetail(wall))
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }

            Spacer(minLength: 0)

            if isBusy {
                ProgressView()
            } else {
                Menu {
                    Button("Rename", systemImage: "pencil", action: onRename)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.auraCardTitle)
                        .foregroundStyle(Color.auraText)
                        .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                }
                .accessibilityLabel("Wall options")
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .padding(.horizontal, AuraSpacing.medium)
    }
}

private struct RenameWallSheet: View {
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(originalTitle: String, onSave: @escaping (String) async throws -> Void) {
        self.onSave = onSave
        _title = State(initialValue: originalTitle)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                AuraTextField(title: "Wall name", text: $title, error: wallTitleValidationError(title))

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
            .navigationTitle("Rename wall")
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
        isSaving = true
        do {
            try await onSave(title)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
