import SwiftUI

struct MainTabView: View {
    let session: SessionStore
    let profile: UserProfile

    @State private var discovery: DiscoveryViewModel
    @State private var statsStore: StatsStore
    @State private var settings: UserSettings
    private let messageService: WallMessageService
    private let publisher: WallPublishService
    private let locationService: LocationService
    private let localStore: LocalStore

    init(session: SessionStore, profile: UserProfile, services: AppServices) {
        self.session = session
        self.profile = profile
        self.messageService = services.messages
        self.publisher = services.publisher
        self.locationService = services.location
        self.localStore = services.localStore
        _statsStore = State(initialValue: StatsStore(economy: services.economy, userID: profile.id))
        _settings = State(initialValue: services.localStore.settings(accountID: profile.id))
        _discovery = State(initialValue: DiscoveryViewModel(
            wallService: services.walls,
            locationService: services.location,
            localStore: services.localStore,
            accountID: profile.id
        ))
    }

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                NavigationStack {
                    DiscoveryMapView(viewModel: discovery, currentUser: profile, messageService: messageService, publisher: publisher, localStore: localStore, statsStore: statsStore)
                }
            }
            Tab("Quests", systemImage: "flag.checkered") {
                QuestsView(statsStore: statsStore)
            }
            Tab("Camera", systemImage: "camera.viewfinder") {
                ARSpikeView(publisher: publisher, locationService: locationService, currentUser: profile)
            }
            Tab("Crew", systemImage: "person.3") {
                PlaceholderTabView(title: "Crew")
            }
            Tab("Me", systemImage: "person.crop.circle") {
                ProfileView(session: session, profile: profile, statsStore: statsStore, localStore: localStore, settings: $settings)
            }
        }
        .tint(Color.auraText)
        .preferredColorScheme(preferredScheme(for: settings.theme))
        .task { statsStore.start() }
        .onDisappear { statsStore.stop() }
    }
}

struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: AuraSpacing.medium) {
            Text(title)
                .font(.auraScreenTitle)
                .foregroundStyle(Color.auraText)
            DevelopmentPill()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
    }
}

struct DevelopmentPill: View {
    var body: some View {
        AuraPill(text: "Placeholder: not built yet")
    }
}

func preferredScheme(for theme: AppTheme) -> ColorScheme? {
    switch theme {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
}
