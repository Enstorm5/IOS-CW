import Foundation

enum QuestKind {
    case discoveries
    case posts
    case drawings
}

struct Quest: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let kind: QuestKind
    let target: Int
    let reward: Int
    let systemImage: String
}

struct DailyCounters: Equatable {
    var day = 0
    var posts = 0
    var drawings = 0
}

enum QuestState: Equatable {
    case inProgress(Int)
    case readyToClaim
    case claimed
}

let readingQuestPool = [
    Quest(id: "readThree", title: "Read 3 walls", detail: "Open 3 different walls within 50 m today.", kind: .discoveries, target: 3, reward: 25, systemImage: "book"),
    Quest(id: "readFive", title: "Read 5 walls", detail: "Open 5 different walls within 50 m today.", kind: .discoveries, target: 5, reward: 40, systemImage: "books.vertical"),
    Quest(id: "readEight", title: "Read 8 walls", detail: "Open 8 different walls within 50 m today.", kind: .discoveries, target: 8, reward: 70, systemImage: "binoculars"),
]

let writingQuestPool = [
    Quest(id: "postOne", title: "Write on a wall", detail: "Post a message on any wall today.", kind: .posts, target: 1, reward: 20, systemImage: "square.and.pencil"),
    Quest(id: "drawOne", title: "Draw on a wall", detail: "Post a hand-drawn message today.", kind: .drawings, target: 1, reward: 30, systemImage: "paintbrush"),
]

let questCatalog = readingQuestPool + writingQuestPool

func quest(withID id: String) -> Quest? {
    questCatalog.first { $0.id == id }
}

// Daily rotation
func questsForDay(_ day: Int) -> [Quest] {
    [readingQuestPool[abs(day) % readingQuestPool.count], writingQuestPool[abs(day) % writingQuestPool.count]]
}

func questClaimID(day: Int, questID: String) -> String {
    "\(day)_\(questID)"
}

func claimedQuestIDs(fromClaimIDs claimIDs: Set<String>, today: Int) -> Set<String> {
    let prefix = "\(today)_"
    return Set(claimIDs.compactMap { claimID in
        claimID.hasPrefix(prefix) ? String(claimID.dropFirst(prefix.count)) : nil
    })
}

func countersForToday(_ all: [DailyCounters], today: Int) -> DailyCounters {
    all.first { $0.day == today } ?? DailyCounters(day: today)
}

func questProgress(_ quest: Quest, stats: UserStats, counters: DailyCounters, today: Int) -> Int {
    let raw: Int
    switch quest.kind {
    case .discoveries: raw = stats.dailyDay == today ? stats.dailyDiscoveries : 0
    case .posts: raw = counters.day == today ? counters.posts : 0
    case .drawings: raw = counters.day == today ? counters.drawings : 0
    }
    return min(raw, quest.target)
}

func questState(_ quest: Quest, stats: UserStats, counters: DailyCounters, claimedQuestIDs: Set<String>, today: Int) -> QuestState {
    if claimedQuestIDs.contains(quest.id) { return .claimed }
    let progress = questProgress(quest, stats: stats, counters: counters, today: today)
    return progress >= quest.target ? .readyToClaim : .inProgress(progress)
}

// Quest reward
func statsAfterQuestClaim(_ stats: UserStats, quest: Quest, today: Int) -> UserStats {
    var updated = stats
    updated.balance += quest.reward
    updated.lifetimeXP += quest.reward
    updated.questsClaimed += 1
    updated.lastClaimID = questClaimID(day: today, questID: quest.id)
    return updated
}

func questStatusText(_ quest: Quest, state: QuestState) -> String {
    switch state {
    case .inProgress(let progress): "\(progress) of \(quest.target) · +\(quest.reward) pts"
    case .readyToClaim: "Ready to claim · +\(quest.reward) pts"
    case .claimed: "Claimed today · +\(quest.reward) pts"
    }
}

func questsSummary(_ states: [QuestState]) -> String {
    let claimed = states.filter { $0 == .claimed }.count
    let ready = states.filter { $0 == .readyToClaim }.count
    if !states.isEmpty && claimed == states.count { return "All of today's quests are done." }
    if ready > 0 { return ready == 1 ? "1 quest is ready to claim in Quests." : "\(ready) quests are ready to claim in Quests." }
    return "\(claimed) of \(states.count) quests done today."
}

func dailyCounters(fields: [String: Any]) -> DailyCounters {
    DailyCounters(
        day: (fields["day"] as? NSNumber)?.intValue ?? 0,
        posts: (fields["posts"] as? NSNumber)?.intValue ?? 0,
        drawings: (fields["drawings"] as? NSNumber)?.intValue ?? 0
    )
}

func counterFields(after counters: DailyCounters, day: Int, wallID: String, messageID: String, isDrawing: Bool) -> [String: Any] {
    let base = counters.day == day ? counters : DailyCounters(day: day)
    return [
        "day": day,
        "posts": base.posts + 1,
        "drawings": base.drawings + (isDrawing ? 1 : 0),
        "lastPostWallID": wallID,
        "lastPostMessageID": messageID,
    ]
}
