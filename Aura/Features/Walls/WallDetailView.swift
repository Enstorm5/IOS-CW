import SwiftUI
import ARKit

struct WallDetailView: View {
    let wall: Wall
    let currentUser: UserProfile
    let publisher: WallPublishService

    @Environment(\.openURL) private var openURL
    @State private var viewModel: WallDetailViewModel
    @State private var isWriting = false
    @State private var isViewingAR = false

    private var canViewInAR: Bool {
        wall.map != nil && ARWorldTrackingConfiguration.isSupported
    }

    init(wall: Wall, currentUser: UserProfile, messageService: WallMessageService, locationService: LocationService, publisher: WallPublishService) {
        self.wall = wall
        self.currentUser = currentUser
        self.publisher = publisher
        _viewModel = State(initialValue: WallDetailViewModel(wall: wall, messageService: messageService, locationService: locationService))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AuraSpacing.small) {
                header
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
            WriteMessageView { text, color in
                try await viewModel.post(text: text, color: color, author: currentUser)
            }
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
        }
        .padding(.horizontal, AuraSpacing.screen)
        .padding(.bottom, AuraSpacing.small)
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
            ForEach(viewModel.messages) { message in
                MessageRow(message: message, isMine: message.authorID == currentUser.id)
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

struct MessageRow: View {
    let message: WallMessage
    let isMine: Bool

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            RoundedRectangle(cornerRadius: AuraRadius.swatch)
                .fill(message.color.swatchColor)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)

            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(isMine ? "You" : message.authorName)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text("\u{201C}\(message.text)\u{201D}")
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }

            Spacer(minLength: 0)

            HStack(spacing: AuraSpacing.xxSmall) {
                Image(systemName: "sparkle")
                Text("\(message.sparkCount)")
            }
            .font(.auraCardTitle)
            .foregroundStyle(Color.auraText)
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .padding(.horizontal, AuraSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(isMine ? "You" : message.authorName) wrote \(message.text). \(message.sparkCount) sparks."))
    }
}
