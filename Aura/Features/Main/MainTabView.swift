import SwiftUI

struct MainTabView: View {
    let session: SessionStore
    let profile: UserProfile

    @State private var discovery: DiscoveryViewModel
    private let messageService: WallMessageService
    private let publisher: WallPublishService
    private let locationService: LocationService

    init(session: SessionStore, profile: UserProfile, services: AppServices) {
        self.session = session
        self.profile = profile
        self.messageService = services.messages
        self.publisher = services.publisher
        self.locationService = services.location
        _discovery = State(initialValue: DiscoveryViewModel(wallService: services.walls, locationService: services.location))
    }

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                NavigationStack {
                    DiscoveryMapView(viewModel: discovery, currentUser: profile, messageService: messageService, publisher: publisher)
                }
            }
            Tab("Quests", systemImage: "flag.checkered") {
                PlaceholderTabView(title: "Quests")
            }
            Tab("Camera", systemImage: "camera.viewfinder") {
                ARSpikeView(publisher: publisher, locationService: locationService, currentUser: profile)
            }
            Tab("Crew", systemImage: "person.3") {
                PlaceholderTabView(title: "Crew")
            }
            Tab("Me", systemImage: "person.crop.circle") {
                MePlaceholderView(session: session, profile: profile)
            }
        }
        .tint(Color.auraText)
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

struct MePlaceholderView: View {
    let session: SessionStore
    let profile: UserProfile

    @State private var isConfirmingSignOut = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: AuraSpacing.medium) {
            Spacer()
            AvatarView(preset: profile.avatarPreset)
            Text(profile.displayName)
                .font(.auraHeading)
                .foregroundStyle(Color.auraText)
            DevelopmentPill()
            if let errorMessage {
                ErrorMessage(text: errorMessage)
            }
            Spacer()
            Button("Sign out") {
                isConfirmingSignOut = true
            }
            .buttonStyle(AuraButtonStyle(kind: .outline))
        }
        .padding(AuraSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.auraBackground)
        .confirmationDialog("Sign out of Aura?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                do {
                    try session.signOut()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct DevelopmentPill: View {
    var body: some View {
        AuraPill(text: "Placeholder: not built yet")
    }
}
