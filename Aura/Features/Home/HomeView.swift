import SwiftUI

struct HomeView: View {
    let currentUser: UserProfile
    let discovery: DiscoveryViewModel
    let statsStore: StatsStore
    let publisher: WallPublishService
    let onSelectWall: (Wall) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var ownedWallCount: Int?
    @State private var isLoadingOwnedWalls = false
    @State private var ownedWallsError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    Text(greetingText(name: currentUser.displayName, hour: Calendar.current.component(.hour, from: .now)))
                        .font(.auraHeading)
                        .foregroundStyle(Color.auraText)

                    pointsSection
                    todayCard
                    nearbyCard
                    myWallsCard
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadOwnedWalls() }
            .refreshable { await loadOwnedWalls() }
        }
        .tint(Color.auraText)
    }

    @ViewBuilder
    private var pointsSection: some View {
        if let stats = statsStore.stats {
            PointsSummaryCard(stats: stats)
        } else if statsStore.statsLoadFailed {
            StatusBanner(systemImage: "exclamationmark.circle", message: "Couldn't load your points. Check your connection and try again.", actionTitle: "Retry") {
                statsStore.restart()
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: AuraSize.control)
        }
    }

    @ViewBuilder
    private var todayCard: some View {
        if let stats = statsStore.stats {
            HomeCard(systemImage: "flag.checkered", title: "Today") {
                HomeDetailText(text: questsSummary(statsStore.todaysQuestStates))
                HomeDetailText(text: streakSummary(stats, today: statsStore.today))
            }
        }
    }

    private var nearbyCard: some View {
        HomeCard(systemImage: "mappin.and.ellipse", title: "Nearby") {
            if !discovery.hasSearched && discovery.isLoading {
                ProgressView()
            } else if !discovery.hasSearched, let errorMessage = discovery.errorMessage {
                HomeDetailText(text: errorMessage)
            } else if !discovery.hasSearched {
                HomeDetailText(text: "Finding walls near you…")
            } else {
                HomeDetailText(text: nearbyWallsSummary(count: discovery.nearbyWalls.count, isOffline: discovery.isShowingSavedWalls))
                ForEach(closestWalls(discovery.nearbyWalls, limit: homeNearbyWallLimit)) { nearby in
                    Button {
                        onSelectWall(nearby.wall)
                    } label: {
                        HStack {
                            Text(nearby.wall.title)
                                .font(.auraSectionLabel)
                                .foregroundStyle(Color.auraText)
                            Spacer()
                            Text(formattedDistance(meters: nearby.distanceMeters))
                                .font(.auraErrorText)
                                .foregroundStyle(Color.auraMuted)
                            Image(systemName: "chevron.right")
                                .font(.auraErrorText)
                                .foregroundStyle(Color.auraMuted)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: AuraSize.minTap)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows this wall on the map")
                }
            }
        }
    }

    private var myWallsCard: some View {
        NavigationLink {
            MyWallsView(publisher: publisher, ownerID: currentUser.id)
        } label: {
            HomeCard(systemImage: "square.on.square.dashed", title: "My walls") {
                if let ownedWallsError {
                    HomeDetailText(text: ownedWallsError)
                } else if let ownedWallCount {
                    HomeDetailText(text: ownedWallsSummary(count: ownedWallCount))
                } else if isLoadingOwnedWalls {
                    ProgressView()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func loadOwnedWalls() async {
        isLoadingOwnedWalls = true
        ownedWallsError = nil
        do {
            ownedWallCount = try await publisher.fetchMyWalls(ownerID: currentUser.id).count
        } catch {
            ownedWallsError = "Couldn't load your walls. Pull down to try again."
        }
        isLoadingOwnedWalls = false
    }
}

private struct HomeCard<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: AuraSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.auraInk)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                .background(Color.auraMint, in: .rect(cornerRadius: AuraRadius.swatch))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(title)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                content
            }
            Spacer(minLength: 0)
        }
        .padding(AuraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
    }
}

private struct HomeDetailText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.auraNotice)
            .foregroundStyle(Color.auraMuted)
    }
}
