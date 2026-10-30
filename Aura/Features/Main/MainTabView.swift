import SwiftUI

// Five tabs
struct MainTabView: View {
    let session: SessionStore
    let profile: UserProfile
    @Binding var requestedTab: AppTab?

    @State private var selectedTab: AppTab = .map
    @State private var discovery: DiscoveryViewModel
    @State private var statsStore: StatsStore
    @State private var crewStore: CrewStore
    @State private var shopStore: ShopStore
    @State private var settings: UserSettings
    @State private var appLock: AppLockStore
    @Environment(\.scenePhase) private var scenePhase
    private let messageService: WallMessageService
    private let publisher: WallPublishService
    private let locationService: LocationService
    private let localStore: LocalStore
    private let widgetSnapshots: WidgetSnapshotService
    private let notifications: NotificationService

    init(session: SessionStore, profile: UserProfile, services: AppServices, requestedTab: Binding<AppTab?>) {
        self.session = session
        self.profile = profile
        _requestedTab = requestedTab
        self.widgetSnapshots = services.widgetSnapshots
        self.notifications = services.notifications
        self.messageService = services.messages
        self.publisher = services.publisher
        self.locationService = services.location
        self.localStore = services.localStore
        _statsStore = State(initialValue: StatsStore(economy: services.economy, userID: profile.id))
        _crewStore = State(initialValue: CrewStore(service: services.crews, userID: profile.id))
        _shopStore = State(initialValue: ShopStore(economy: services.economy, userID: profile.id))
        _settings = State(initialValue: services.localStore.settings(accountID: profile.id))
        _appLock = State(initialValue: AppLockStore(biometric: services.biometric))
        _discovery = State(initialValue: DiscoveryViewModel(
            wallService: services.walls,
            locationService: services.location,
            localStore: services.localStore,
            accountID: profile.id
        ))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Map", systemImage: "map", value: .map) {
                NavigationStack {
                    DiscoveryMapView(viewModel: discovery, currentUser: profile, messageService: messageService, publisher: publisher, localStore: localStore, statsStore: statsStore)
                }
            }
            Tab("Quests", systemImage: "flag.checkered", value: .quests) {
                QuestsView(statsStore: statsStore, shop: shopStore)
            }
            Tab("Camera", systemImage: "camera.viewfinder", value: .camera) {
                ARSpikeView(publisher: publisher, locationService: locationService, currentUser: profile, statsStore: statsStore, onWriteOnWall: { wall in
                    discovery.open(wall, startWriting: true)
                    selectedTab = .map
                })
            }
            Tab("Crew", systemImage: "person.3", value: .crew) {
                CrewView(store: crewStore, profile: profile)
            }
            Tab("Me", systemImage: "person.crop.circle", value: .me) {
                ProfileView(session: session, profile: profile, statsStore: statsStore, localStore: localStore, appLock: appLock, publisher: publisher, crewStore: crewStore, notifications: notifications, settings: $settings)
            }
        }
        .tint(Color.auraText)
        .environment(\.ownedShopItems, shopStore.ownedItemIDs)
        .preferredColorScheme(preferredScheme(for: settings.theme))
        .overlay {
            if appLock.isLocked {
                AppLockView(lock: appLock, onSignOut: signOutFromLock)
            } else if appLock.isCovered {
                PrivacyCoverView()
            }
        }
        .task {
            appLock.configure(enabled: settings.appLockEnabled, lockNow: true)
            statsStore.start()
            crewStore.start()
            shopStore.start()
        }
        .onChange(of: settings.appLockEnabled) {
            appLock.configure(enabled: settings.appLockEnabled, lockNow: false)
        }
        .onChange(of: requestedTab, initial: true) {
            if let requestedTab {
                selectedTab = requestedTab
                self.requestedTab = nil
            }
        }
        .onChange(of: statsStore.stats) {
            if let stats = statsStore.stats {
                saveWidgetSnapshot(stats)
                Task { await crewStore.syncScore(stats: stats) }
                refreshQuestReminders()
            }
        }
        .onChange(of: statsStore.dayCounters) {
            refreshQuestReminders()
        }
        .onChange(of: settings.questRemindersEnabled) {
            if settings.questRemindersEnabled {
                refreshQuestReminders()
            } else {
                notifications.cancelQuestReminders()
            }
        }
        .onChange(of: statsStore.claimIDs) {
            if let stats = statsStore.stats {
                saveWidgetSnapshot(stats)
            }
            refreshQuestReminders()
        }
        .onChange(of: crewStore.members) {
            if let stats = statsStore.stats {
                Task { await crewStore.syncScore(stats: stats) }
            }
        }
        .onChange(of: scenePhase) {
            appLock.scenePhaseChanged(to: scenePhase, now: Date())
            if scenePhase == .active {
                refreshQuestReminders()
            }
        }
        .onDisappear {
            statsStore.stop()
            crewStore.stop()
            shopStore.stop()
        }
    }

    // Reschedule reminders
    private func refreshQuestReminders() {
        guard settings.questRemindersEnabled, let stats = statsStore.stats else { return }
        let planned = plannedQuestReminders(now: Date(), stats: stats, todayStates: statsStore.todaysQuestStates)
        notifications.replaceQuestReminders(planned)
    }

    private func saveWidgetSnapshot(_ stats: UserStats) {
        widgetSnapshots.save(widgetSnapshot(from: stats, questStates: statsStore.todaysQuestStates, accountID: profile.id, now: Date()))
    }

    private func signOutFromLock() {
        try? localStore.deleteAccountData(accountID: profile.id)
        try? session.signOut()
    }
}

func preferredScheme(for theme: AppTheme) -> ColorScheme? {
    switch theme {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
}
