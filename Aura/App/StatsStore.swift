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
    private(set) var statsLoadFailed = false
    private(set) var claimingQuestID: String?
    private(set) var questMessage: String?
    private(set) var claimIDs: Set<String> = []
    private(set) var dayCounters: [DailyCounters] = []

    let userID: String
    private let economy: EconomyService
    private var listener: ListenerRegistration?
    private var claimsListener: ListenerRegistration?
    private var countersListener: ListenerRegistration?
    private var wallsClaimedThisSession: Set<String> = []

    init(economy: EconomyService, userID: String) {
        self.economy = economy
        self.userID = userID
    }

    var today: Int { dayNumber(for: Date()) }

    var todaysQuests: [Quest] { questsForDay(today) }

    var claimedTodayIDs: Set<String> { claimedQuestIDs(fromClaimIDs: claimIDs, today: today) }

    func state(of quest: Quest) -> QuestState {
        questState(
            quest,
            stats: stats ?? UserStats(),
            counters: countersForToday(dayCounters, today: today),
            claimedQuestIDs: claimedTodayIDs,
            today: today
        )
    }

    var todaysQuestStates: [QuestState] { todaysQuests.map(state(of:)) }

    func start() {
        guard listener == nil else { return }
        listener = economy.listenToStats(userID: userID) { [weak self] newStats, failed in
            guard let self else { return }
            statsLoadFailed = failed
            if !failed {
                stats = newStats
            }
        }
        let sinceDay = today - 1
        claimsListener = economy.listenToQuestClaims(userID: userID, sinceDay: sinceDay) { [weak self] ids in
            self?.claimIDs = ids
        }
        countersListener = economy.listenToDailyCounters(userID: userID, sinceDay: sinceDay) { [weak self] counters in
            self?.dayCounters = counters
        }
        Task { try? await economy.createStatsIfMissing(userID: userID) }
    }

    func stop() {
        listener?.remove()
        listener = nil
        claimsListener?.remove()
        claimsListener = nil
        countersListener?.remove()
        countersListener = nil
    }

    func restart() {
        stop()
        statsLoadFailed = false
        start()
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

    func claimQuest(_ quest: Quest) async {
        guard claimingQuestID == nil else { return }
        claimingQuestID = quest.id
        questMessage = nil

        do {
            switch try await economy.claimQuest(userID: userID, quest: quest, now: Date()) {
            case .claimed(let updated):
                stats = updated
                questMessage = "+\(quest.reward) points claimed."
            case .notReady(let reason):
                questMessage = reason
            }
        } catch {
            questMessage = "Couldn't claim the quest. Check your connection and try again."
        }
        claimingQuestID = nil
    }
}
