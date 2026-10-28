import SwiftUI

struct ProfileView: View {
    let session: SessionStore
    let profile: UserProfile
    let statsStore: StatsStore
    let localStore: LocalStore
    let appLock: AppLockStore
    let publisher: WallPublishService
    let crewStore: CrewStore
    @Binding var settings: UserSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.medium) {
                    AvatarView(preset: profile.avatarPreset, size: AuraSize.profileAvatar)
                    Text(profile.displayName)
                        .font(.auraHeading)
                        .foregroundStyle(Color.auraText)
                    if let stats = statsStore.stats {
                        AuraPill(text: "Lv \(level(forXP: stats.lifetimeXP))")
                    }
                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(.auraNotice)
                            .foregroundStyle(Color.auraMuted)
                            .multilineTextAlignment(.center)
                    }
                    if !profile.interests.isEmpty {
                        Text(profile.interests.map(\.title).joined(separator: " · "))
                            .font(.auraErrorText)
                            .foregroundStyle(Color.auraMuted)
                            .multilineTextAlignment(.center)
                    }

                    if let stats = statsStore.stats {
                        PointsSummaryCard(stats: stats)
                    }

                    VStack(spacing: AuraSpacing.small) {
                        NavigationLink {
                            EditProfileView(session: session, profile: profile)
                        } label: {
                            ProfileLinkRow(systemImage: "person.crop.circle", title: "Edit profile", detail: "Name, look, bio, interests")
                        }
                        NavigationLink {
                            MyWallsView(publisher: publisher, ownerID: profile.id)
                        } label: {
                            ProfileLinkRow(systemImage: "square.on.square.dashed", title: "My walls", detail: "\(statsStore.stats?.wallsPublished ?? 0) published")
                        }
                        NavigationLink {
                            BadgesView(stats: statsStore.stats ?? UserStats())
                        } label: {
                            ProfileLinkRow(systemImage: "rosette", title: "Badges", detail: "\(badges(for: statsStore.stats ?? UserStats()).filter(\.isEarned).count) earned")
                        }
                        NavigationLink {
                            SettingsView(session: session, profile: profile, localStore: localStore, appLock: appLock, crewStore: crewStore, statsStore: statsStore, settings: $settings)
                        } label: {
                            ProfileLinkRow(systemImage: "gearshape", title: "Settings", detail: "Theme, app lock, location, account")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProfileLinkRow: View {
    let systemImage: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.auraInk)
                .frame(width: AuraSize.messageSwatch, height: AuraSize.messageSwatch)
                .background(Color.auraLilac, in: .rect(cornerRadius: AuraRadius.swatch))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(title)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text(detail)
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.auraMuted)
                .accessibilityHidden(true)
        }
        .padding(AuraSpacing.medium)
        .frame(minHeight: AuraSize.minTap)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
    }
}
