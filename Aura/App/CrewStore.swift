import Foundation
import Observation
import FirebaseFirestore

@MainActor @Observable
final class CrewStore {
    private(set) var hasLoadedMembership = false
    private(set) var membershipLoadFailed = false
    private(set) var crewID: String?
    private(set) var crew: Crew?
    private(set) var members: [CrewMember] = []
    private(set) var isWorking = false
    private(set) var actionError: String?
    private(set) var notice: String?

    let userID: String
    private let service: CrewService
    private var membershipListener: ListenerRegistration?
    private var crewListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?
    private var isLeaving = false
    private var isSyncingScore = false

    init(service: CrewService, userID: String) {
        self.service = service
        self.userID = userID
    }

    var me: CrewMember? {
        members.first { $0.id == userID }
    }

    var rankings: [CrewRanking] {
        rankedCrewMembers(members)
    }

    var sortedMembers: [CrewMember] {
        guard let crew else { return [] }
        return sortedCrewMembers(members, ownerID: crew.ownerID)
    }

    func start() {
        guard membershipListener == nil else { return }
        membershipListener = service.listenToMembership(userID: userID) { [weak self] newCrewID, failed in
            self?.membershipChanged(to: newCrewID, failed: failed)
        }
    }

    func stop() {
        membershipListener?.remove()
        membershipListener = nil
        stopCrewListeners()
    }

    func retry() {
        stop()
        membershipLoadFailed = false
        start()
    }

    func clearMessages() {
        actionError = nil
        notice = nil
    }

    func create(name: String, profile: UserProfile) async throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nameError = crewNameValidationError(cleaned) {
            throw UserFacingError(message: nameError)
        }
        try await runAction(failureMessage: "Couldn't start the crew. Check your connection and try again.") {
            try await self.service.createCrew(name: cleaned, profile: profile)
        }
    }

    func findInvite(code: String) async throws -> CrewInvite {
        if let codeError = inviteCodeValidationError(code) {
            throw UserFacingError(message: codeError)
        }
        let invite: CrewInvite?
        do {
            invite = try await service.findInvite(code: normalizedInviteCode(code))
        } catch {
            throw UserFacingError(message: "Couldn't check the code. Check your connection and try again.")
        }
        guard let invite else {
            throw UserFacingError(message: "No crew uses that code. Check it with your friend.")
        }
        return invite
    }

    func join(_ invite: CrewInvite, profile: UserProfile) async throws {
        try await runAction(failureMessage: "Couldn't join \(invite.crewName). The crew may be full (\(maximumCrewMembers) members) or the code may have changed.") {
            try await self.service.joinCrew(invite, profile: profile)
        }
    }

    func leave() async {
        isLeaving = true
        do {
            try await runAction(failureMessage: "Couldn't leave the crew. Check your connection and try again.") {
                try await self.service.leaveCurrentCrew(userID: self.userID)
            }
            stopCrewListeners()
            crewID = nil
            crew = nil
            members = []
        } catch {
            actionError = error.localizedDescription
        }
        isLeaving = false
    }

    func setRankingOptIn(_ isOn: Bool, stats: UserStats?) async {
        guard let crewID else { return }
        guard let stats else {
            actionError = "Your points are still loading. Try again in a moment."
            return
        }
        let score = rankingScore(from: stats, showOnRankings: isOn)
        do {
            try await runAction(failureMessage: "Couldn't change your ranking setting. Check your connection and try again.") {
                try await self.service.saveRankingScore(score, crewID: crewID, userID: self.userID)
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    // Share score
    func syncScore(stats: UserStats) async {
        guard let crewID, let me, needsScoreSync(member: me, stats: stats), !isSyncingScore, !isWorking else { return }
        isSyncingScore = true
        try? await service.saveRankingScore(rankingScore(from: stats, showOnRankings: true), crewID: crewID, userID: userID)
        isSyncingScore = false
    }

    func remove(_ member: CrewMember) async {
        guard let crewID else { return }
        do {
            try await runAction(failureMessage: "Couldn't remove \(member.displayName). Check your connection and try again.") {
                try await self.service.removeMember(member.id, crewID: crewID)
            }
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func runAction(failureMessage: String, action: () async throws -> Void) async throws {
        guard !isWorking else { return }
        isWorking = true
        actionError = nil
        notice = nil
        defer { isWorking = false }
        do {
            try await action()
        } catch {
            throw UserFacingError(message: failureMessage)
        }
    }

    private func membershipChanged(to newCrewID: String?, failed: Bool) {
        if failed {
            membershipLoadFailed = !hasLoadedMembership
            return
        }
        hasLoadedMembership = true
        membershipLoadFailed = false
        guard newCrewID != crewID else { return }

        stopCrewListeners()
        crewID = newCrewID
        crew = nil
        members = []
        guard let newCrewID else { return }

        crewListener = service.listenToCrew(crewID: newCrewID) { [weak self] loaded, failed in
            self?.crewChanged(loaded, failed: failed, crewID: newCrewID)
        }
        membersListener = service.listenToMembers(crewID: newCrewID) { [weak self] loaded in
            guard let self, let loaded, crewID == newCrewID else { return }
            members = loaded
        }
    }

    // Removed from crew
    private func crewChanged(_ loaded: Crew?, failed: Bool, crewID listenedCrewID: String) {
        guard crewID == listenedCrewID, !isLeaving else { return }
        if let loaded {
            crew = loaded
            return
        }
        let lostName = crew?.name
        stopCrewListeners()
        crewID = nil
        crew = nil
        members = []
        notice = removedFromCrewMessage(crewName: lostName)
        Task { try? await service.clearMembership(userID: userID) }
    }

    private func stopCrewListeners() {
        crewListener?.remove()
        crewListener = nil
        membersListener?.remove()
        membersListener = nil
    }
}
