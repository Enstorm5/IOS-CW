import Foundation
import Observation
import FirebaseFirestore

enum DiscoveryClaimResult {
    case awarded
    case alreadyDiscovered
    case failed
}

@MainActor @Observable
final class StatsStore {
    private(set) var stats: UserStats?
    private(set) var isClaimingQuest = false
    private(set) var questMessage: String?

    let userID: String
    private let economy: EconomyService
    private var listener: ListenerRegistration?
    private var wallsClaimedThisSession: Set<String> = []

    init(economy: EconomyService, userID: String) {
        self.economy = economy
        self.userID = userID
    }

    var today: Int { dayNumber(for: Date()) }

    func start() {
        guard listener == nil else { return }
        listener = economy.listenToStats(userID: userID) { [weak self] newStats in
            self?.stats = newStats
        }
        Task { try? await economy.createStatsIfMissing(userID: userID) }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func claimDiscovery(wallID: String) async -> DiscoveryClaimResult {
        guard !wallsClaimedThisSession.contains(wallID) else { return .alreadyDiscovered }
        wallsClaimedThisSession.insert(wallID)

        do {
            switch try await economy.claimDiscovery(userID: userID, wallID: wallID, now: Date()) {
            case .awarded(let updated):
                stats = updated
                return .awarded
            case .alreadyDiscovered:
                return .alreadyDiscovered
            }
        } catch {
            wallsClaimedThisSession.remove(wallID)
            return .failed
        }
    }

    func claimDailyQuest() async {
        guard !isClaimingQuest else { return }
        isClaimingQuest = true
        questMessage = nil

        do {
            switch try await economy.claimDailyQuest(userID: userID, now: Date()) {
            case .claimed(let updated):
                stats = updated
                questMessage = "+\(dailyQuestRewardPoints) points claimed."
            case .notReady(let reason):
                questMessage = reason
            }
        } catch {
            questMessage = "Couldn't claim the quest. Check your connection and try again."
        }
        isClaimingQuest = false
    }
}
