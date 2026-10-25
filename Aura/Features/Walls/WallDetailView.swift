import SwiftUI

struct WallDetailView: View {
    let wall: Wall
    let currentUserID: String

    @State private var viewModel: WallDetailViewModel

    init(wall: Wall, currentUserID: String, messageService: WallMessageService) {
        self.wall = wall
        self.currentUserID = currentUserID
        _viewModel = State(initialValue: WallDetailViewModel(wallID: wall.id, messageService: messageService))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AuraSpacing.small) {
                header
                content
            }
            .padding(.vertical, AuraSpacing.medium)
        }
        .background(Color.auraBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !viewModel.hasLoaded {
                await viewModel.loadFirstPage()
            }
        }
        .refreshable {
            await viewModel.loadFirstPage()
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
    private var content: some View {
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
                MessageRow(message: message, isMine: message.authorID == currentUserID)
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
}

struct MessageRow: View {
    let message: WallMessage
    let isMine: Bool

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            RoundedRectangle(cornerRadius: AuraRadius.swatch)
                .fill(swatchColor)
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

    private var swatchColor: Color {
        switch message.color {
        case .magenta: .auraMagenta
        case .mint: .auraMint
        case .yellow: .auraYellow
        case .ink: .auraInk
        }
    }
}
