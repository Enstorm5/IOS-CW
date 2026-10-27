import SwiftUI
import UIKit

struct CrewView: View {
    let store: CrewStore
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.medium) {
                    if let notice = store.notice {
                        StatusBanner(systemImage: "person.crop.circle.badge.xmark", message: notice)
                    }

                    if store.membershipLoadFailed {
                        Text("Crew")
                            .font(.auraScreenTitle)
                            .foregroundStyle(Color.auraText)
                        StatusBanner(systemImage: "wifi.exclamationmark", message: "Couldn't load your crew. Check your connection and try again.", actionTitle: "Retry") {
                            store.retry()
                        }
                    } else if !store.hasLoadedMembership || (store.crewID != nil && store.crew == nil) {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: AuraSize.control)
                    } else if let crew = store.crew {
                        CrewDetailContent(store: store, crew: crew)
                    } else {
                        NoCrewContent(store: store, profile: profile)
                    }
                }
                .padding(AuraSpacing.screen)
            }
            .background(Color.auraBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct NoCrewContent: View {
    let store: CrewStore
    let profile: UserProfile

    @State private var crewName = ""
    @State private var inviteCode = ""
    @State private var createError: String?
    @State private var joinError: String?
    @State private var foundInvite: CrewInvite?
    @State private var isFinding = false

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.medium) {
            Text("Crew")
                .font(.auraScreenTitle)
                .foregroundStyle(Color.auraText)
            Text("Explore with friends. Start a crew or join one with an invite code. You can be in one crew at a time.")
                .font(.auraNotice)
                .foregroundStyle(Color.auraMuted)

            CrewCard(title: "Start a crew") {
                AuraTextField(title: "Crew name", text: $crewName, error: createError)
                Button {
                    Task { await create() }
                } label: {
                    if store.isWorking {
                        ProgressView().tint(Color.auraInk)
                    } else {
                        Text("Start crew")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .highlight))
                .disabled(store.isWorking)
            }

            CrewCard(title: "Join a crew") {
                AuraTextField(title: "Invite code", text: $inviteCode, error: joinError)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button {
                    Task { await findInvite() }
                } label: {
                    if isFinding {
                        ProgressView().tint(Color.auraText)
                    } else {
                        Text("Find crew")
                    }
                }
                .buttonStyle(AuraButtonStyle(kind: .outline))
                .disabled(isFinding || store.isWorking)
            }
        }
        .confirmationDialog(
            "Join this crew?",
            isPresented: Binding(get: { foundInvite != nil }, set: { if !$0 { foundInvite = nil } }),
            titleVisibility: .visible,
            presenting: foundInvite
        ) { invite in
            Button("Join \(invite.crewName)") {
                Task { await join(invite) }
            }
        } message: { invite in
            Text("Members of \(invite.crewName) see your name and avatar.")
        }
    }

    private func create() async {
        createError = nil
        do {
            try await store.create(name: crewName, profile: profile)
        } catch {
            createError = error.localizedDescription
        }
    }

    private func findInvite() async {
        joinError = nil
        isFinding = true
        do {
            foundInvite = try await store.findInvite(code: inviteCode)
        } catch {
            joinError = error.localizedDescription
        }
        isFinding = false
    }

    private func join(_ invite: CrewInvite) async {
        do {
            try await store.join(invite, profile: profile)
        } catch {
            joinError = error.localizedDescription
        }
    }
}

private struct CrewDetailContent: View {
    let store: CrewStore
    let crew: Crew

    @State private var isConfirmingLeave = false
    @State private var removingMember: CrewMember?
    @State private var didCopyCode = false

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(crew.name)
                    .font(.auraScreenTitle)
                    .foregroundStyle(Color.auraText)
                Spacer()
                AuraPill(text: crewMemberCountText(crew.memberCount))
            }

            if let actionError = store.actionError {
                ErrorMessage(text: actionError)
            }

            CrewCard(title: "Invite code") {
                Text(crew.inviteCode)
                    .font(.auraHeading)
                    .monospaced()
                    .foregroundStyle(Color.auraText)
                    .accessibilityLabel(Text(crew.inviteCode.map(String.init).joined(separator: " ")))
                HStack(spacing: AuraSpacing.small) {
                    ShareLink(item: crewInviteShareText(crew)) {
                        Text("Share invite")
                    }
                    .buttonStyle(AuraButtonStyle(kind: .highlight))
                    Button(didCopyCode ? "Copied" : "Copy code") {
                        UIPasteboard.general.string = crew.inviteCode
                        didCopyCode = true
                    }
                    .buttonStyle(AuraButtonStyle(kind: .outline))
                }
            }

            Text("Members")
                .font(.auraSectionLabel)
                .foregroundStyle(Color.auraMuted)

            ForEach(store.sortedMembers) { member in
                CrewMemberRow(
                    member: member,
                    role: crewMemberRole(member, crew: crew, currentUserID: store.userID),
                    onRemove: canRemoveCrewMember(member.id, currentUserID: store.userID, crew: crew) ? { removingMember = member } : nil
                )
            }

            Button("Leave crew", role: .destructive) {
                isConfirmingLeave = true
            }
            .buttonStyle(AuraButtonStyle(kind: .outline))
            .disabled(store.isWorking)
        }
        .confirmationDialog("Leave \(crew.name)?", isPresented: $isConfirmingLeave, titleVisibility: .visible) {
            Button("Leave crew", role: .destructive) {
                Task { await store.leave() }
            }
        } message: {
            Text(leaveCrewMessage(plan: crewLeavePlan(crew: crew, members: store.members, leavingID: store.userID), members: store.members))
        }
        .confirmationDialog(
            "Remove from crew?",
            isPresented: Binding(get: { removingMember != nil }, set: { if !$0 { removingMember = nil } }),
            titleVisibility: .visible,
            presenting: removingMember
        ) { member in
            Button("Remove \(member.displayName)", role: .destructive) {
                Task { await store.remove(member) }
            }
        } message: { member in
            Text("\(member.displayName) loses access to the crew. They can rejoin with the invite code.")
        }
    }
}

private struct CrewMemberRow: View {
    let member: CrewMember
    let role: String
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: AuraSpacing.medium) {
            AvatarView(preset: member.avatarPreset, size: AuraSize.messageSwatch)
            VStack(alignment: .leading, spacing: AuraSpacing.xxSmall) {
                Text(member.displayName)
                    .font(.auraCardTitle)
                    .foregroundStyle(Color.auraText)
                Text(role)
                    .font(.auraNotice)
                    .foregroundStyle(Color.auraMuted)
            }
            Spacer(minLength: 0)
            if let onRemove {
                Menu {
                    Button("Remove from crew", systemImage: "person.badge.minus", role: .destructive, action: onRemove)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.auraCardTitle)
                        .foregroundStyle(Color.auraText)
                        .frame(width: AuraSize.minTap, height: AuraSize.minTap)
                }
                .accessibilityLabel("Options for \(member.displayName)")
            }
        }
        .padding(AuraSpacing.medium)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.row))
        .accessibilityElement(children: .contain)
    }
}

private struct CrewCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.small) {
            Text(title)
                .font(.auraCardTitle)
                .foregroundStyle(Color.auraText)
            content
        }
        .padding(AuraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.auraCard, in: .rect(cornerRadius: AuraRadius.card))
    }
}
