import SwiftUI
import ARKit

// Wall screen
struct WallDetailView: View {
    let wall: Wall
    let currentUser: UserProfile
    let publisher: WallPublishService
    let onDeleted: (String) -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var viewModel: WallDetailViewModel
    @State private var isWriting = false
    @State private var isViewingAR = false
    @State private var editingMessage: WallMessage?
    @State private var deletingMessage: WallMessage?

    private var canViewInAR: Bool {
        wall.map != nil && ARWorldTrackingConfiguration.isSupported
    }

    init(wall: Wall, currentUser: UserProfile, messageService: WallMessageService, locationService: LocationService, publisher: WallPublishService, localStore: LocalStore, statsStore: StatsStore, onDeleted: @escaping (String) -> Void = { _ in }) {
        self.onDeleted = onDeleted
        self.wall = wall
        self.currentUser = currentUser
        self.publisher = publisher
        _viewModel = State(initialValue: WallDetailViewModel(wall: wall, messageService: messageService, locationService: locationService, localStore: localStore, accountID: currentUser.id, statsStore: statsStore))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AuraSpacing.small) {
                header
                if let deleteError {
                    ErrorMessage(text: deleteError)
                        .padding(.horizontal, AuraSpacing.screen)
                }
                if viewModel.isUnlocked {
                    unlockedContent
                } else {
                    lockedContent
                }
            }
            .padding(.vertical, AuraSpacing.medium)
        }
        .background(Color.auraBackground)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isUnlocked {
                HStack(spacing: AuraSpacing.small) {
                    if canViewInAR {
                        Button("View in AR") {
                            isViewingAR = true
                        }
                        .buttonStyle(AuraButtonStyle())
                    }
                    Button("Write on wall") {
                        isWriting = true
                    }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                }
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.vertical, AuraSpacing.small)
                .background(Color.auraBackground)
            }
        }
        .sheet(isPresented: $isWriting) {
            WriteMessageView(
                initialDraft: viewModel.savedDraft(),
                onPost: { content in
                    try await viewModel.post(content, author: currentUser)
                },
                onSaveDraft: { text, color in viewModel.saveDraft(text: text, color: color) },
                onDiscardDraft: { viewModel.discardDraft() }
            )
        }
        .sheet(item: $editingMessage) { message in
            EditMessageSheet(originalText: message.text) { newText in
                try await viewModel.edit(message, newText: newText)
            }
        }
        .confirmationDialog(
            "Delete this message?",
            isPresented: Binding(get: { deletingMessage != nil }, set: { if !$0 { deletingMessage = nil } }),
            titleVisibility: .visible,
            presenting: deletingMessage
        ) { message in
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(message) }
            }
        } message: { _ in
            Text("It's removed from the wall for everyone.")
        }
        .fullScreenCover(isPresented: $isViewingAR) {
            WallARView(wall: wall, currentUser: currentUser, detailViewModel: viewModel, publisher: publisher)
        }
        .onAppear { viewModel.appeared() }
        .task { await viewModel.requestFreshFix() }
        .onDisappear { viewModel.disappeared() }
        .task(id: viewModel.locationService.latestLocation) {
            await viewModel.refreshProximity(now: .now)
        }
        .task(id: viewModel.locationService.access) {
            await viewModel.refreshProximity(now: .now)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .confirmationDialog("Delete this wall?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete wall", role: .destructive) {
                Task { await deleteWall() }
            }
        } message: {
            Text("The wall and its AR map are removed for everyone, and its messages disappear with it. Points aren't refunded.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: AuraSpacing.small) {
            Text(wall.title)
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
            if wall.kind == .sponsored {
                AuraPill(text: "Sponsored")
            }
            Spacer(minLength: 0)
            if isWallOwner(wall, userID: currentUser.id) {
                ownerMenu
            }
        }
        .padding(.horizontal, AuraSpacing.screen)
        .padding(.bottom, AuraSpacing.small)
    }

    // Owner delete
    private var ownerMenu: some View {
        Group {
            if isDeleting {
                ProgressView()
            } else {
                Menu {
                    Button("Delete wall", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.auraCardTitle)
                        .foregroundStyle(Color.auraText)
                        .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                }
                .accessibilityLabel("Wall options")
            }
        }
    }

    private func deleteWall() async {
        isDeleting = true
        deleteError = nil
        do {
            try await publisher.deleteWall(wallID: wall.id)
            onDeleted(wall.id)
            dismiss()
        } catch {
            deleteError = "Couldn't delete the wall. Check your connection and try again."
        }
        isDeleting = false
    }

    @ViewBuilder
    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            Label(lockedWallMessage(for: viewModel.proximity, policy: wallReadingPolicy) ?? "", systemImage: "lock.fill")
                .font(.auraNotice)
                .foregroundStyle(Color.auraText)

            if viewModel.proximity == .locationOff || viewModel.proximity == .approximateLocation {
                Button("Open Settings", action: openSettings)
                    .font(.auraLink)
                    .foregroundStyle(Color.auraText)
                    .underline()
                    .frame(minHeight: AuraSize.minTap)
            }
        }
        .padding(AuraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
        .padding(.horizontal, AuraSpacing.medium)

        if let teaser = viewModel.teaser {
            Text(messageCountText(teaser.messageCount))
                .font(.auraSectionLabel)
                .foregroundStyle(Color.auraMuted)
                .padding(.horizontal, AuraSpacing.screen)
                .padding(.top, AuraSpacing.small)

            if let latest = teaser.latestMessage {
                MessageRow(message: latest, isMine: false)
                    .blur(radius: AuraSize.teaserBlur)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        } else if viewModel.isLoadingTeaser {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: AuraSize.control)
        } else if let errorMessage = viewModel.errorMessage {
            StatusBanner(systemImage: "wifi.exclamationmark", message: errorMessage, actionTitle: "Retry") {
                Task { await viewModel.loadTeaser() }
            }
        }
    }

    @ViewBuilder
    private var unlockedContent: some View {
        if let discoveryBanner = viewModel.discoveryBanner {
            StatusBanner(systemImage: "sparkles", message: discoveryBanner)
        }
        if let actionError = viewModel.actionError {
            StatusBanner(systemImage: "exclamationmark.circle", message: actionError)
        }
        if viewModel.isLoading && viewModel.messages.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: AuraSize.control)
        } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
            StatusBanner(systemImage: "wifi.exclamationmark", message: errorMessage, actionTitle: "Retry") {
                Task { await viewModel.loadFirstPage() }
            }
        } else if viewModel.hasLoaded && viewModel.messages.isEmpty {
            StatusBanner(systemImage: "text.bubble", message: "No messages on this wall yet.")
        } else {
            if viewModel.isShowingSavedMessages {
                StatusBanner(systemImage: "icloud.slash", message: offlineSavedText(viewModel.showingSavedMessagesSince, now: .now), actionTitle: "Retry") {
                    Task { await viewModel.loadFirstPage() }
                }
            }
            ForEach(viewModel.messages) { message in
                MessageRow(
                    message: message,
                    isMine: message.authorID == currentUser.id,
                    isSparked: viewModel.sparkedMessageIDs.contains(message.id),
                    isSparking: viewModel.sparkingMessageIDs.contains(message.id),
                    onSpark: canSpark(message, userID: currentUser.id) ? { Task { await viewModel.toggleSpark(message) } } : nil,
                    onEdit: canEdit(message, userID: currentUser.id) ? { editingMessage = message } : nil,
                    onDelete: canDelete(message, userID: currentUser.id) ? { deletingMessage = message } : nil
                )
            }

            if let errorMessage = viewModel.errorMessage {
                StatusBanner(systemImage: "exclamationmark.circle", message: errorMessage)
            }

            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: AuraSize.control)
            } else if viewModel.canLoadMore {
                Button("Load more") {
                    Task { await viewModel.loadNextPage() }
                }
                .buttonStyle(AuraPillButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

// Message row
struct MessageRow: View {
    let message: WallMessage
    let isMine: Bool
    var isSparked = false
    var isSparking = false
    var onSpark: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            RoundedRectangle(cornerRadius: AuraRadius.swatch)
                .fill(message.color.swatchColor)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)

            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(isMine ? "You" : message.authorName)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                if message.contentType == .drawing, let drawing = message.drawing {
                    DrawingThumbnail(drawing: drawing)
                } else {
                    Text("\u{201C}\(message.text)\u{201D}")
                        .font(.auraNotice)
                        .foregroundStyle(Color.auraMuted)
                }
            }

            Spacer(minLength: 0)

            sparkControl

            if onEdit != nil || onDelete != nil {
                Menu {
                    if let onEdit {
                        Button("Edit", systemImage: "pencil", action: onEdit)
                    }
                    if let onDelete {
                        Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.auraCardTitle)
                        .foregroundStyle(Color.auraText)
                        .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                }
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .padding(.horizontal, AuraSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(messageAccessibilityLabel(message, isMine: isMine)))
        .accessibilityActions {
            if let onSpark {
                Button(isSparked ? "Remove spark" : "Give a spark", action: onSpark)
            }
            if let onEdit {
                Button("Edit", action: onEdit)
            }
            if let onDelete {
                Button("Delete", action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var sparkControl: some View {
        let label = HStack(spacing: AuraSpacing.xxSmall) {
            Image(systemName: isSparked ? "sparkles" : "sparkle")
            Text("\(message.sparkCount)")
        }
        .font(.auraCardTitle)
        .foregroundStyle(isSparked ? Color.auraInk : Color.auraText)
        .padding(.horizontal, AuraSpacing.small)
        .frame(minHeight: AuraSize.minTap)
        .background(isSparked ? Color.auraYellow : Color.clear, in: .capsule)

        if let onSpark {
            Button(action: onSpark) { label }
                .buttonStyle(.plain)
                .disabled(isSparking)
        } else {
            label
        }
    }
}
