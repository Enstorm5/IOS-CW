import Foundation

let crewNameLengthRange = 2...30
let maximumCrewMembers = 20
let weeklyWallsPerParticipant = 5
let inviteCodeLength = 6
let inviteCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

// Crew name check
func crewNameValidationError(_ name: String) -> String? {
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty { return "Give your crew a name." }
    if cleaned.count < crewNameLengthRange.lowerBound { return "Use at least \(crewNameLengthRange.lowerBound) characters." }
    if cleaned.count > crewNameLengthRange.upperBound { return "Use \(crewNameLengthRange.upperBound) characters or fewer." }
    return nil
}

func normalizedInviteCode(_ code: String) -> String {
    code.uppercased().filter { !$0.isWhitespace && $0 != "-" }
}

// Invite code check
func inviteCodeValidationError(_ code: String) -> String? {
    let cleaned = normalizedInviteCode(code)
    if cleaned.isEmpty { return "Enter the invite code from your friend." }
    if cleaned.count != inviteCodeLength || !cleaned.allSatisfy({ inviteCodeAlphabet.contains($0) }) {
        return "Invite codes have \(inviteCodeLength) letters and numbers."
    }
    return nil
}

func inviteCode(fromIndexes indexes: [Int]) -> String {
    String(indexes.prefix(inviteCodeLength).map { inviteCodeAlphabet[abs($0) % inviteCodeAlphabet.count] })
}

// Generate invite code
func randomInviteCode() -> String {
    inviteCode(fromIndexes: (0..<inviteCodeLength).map { _ in Int.random(in: 0..<inviteCodeAlphabet.count) })
}

// Member order
func sortedCrewMembers(_ members: [CrewMember], ownerID: String) -> [CrewMember] {
    members.sorted { first, second in
        if (first.id == ownerID) != (second.id == ownerID) { return first.id == ownerID }
        if first.joinedAt != second.joinedAt { return first.joinedAt < second.joinedAt }
        return first.id < second.id
    }
}

// Leave outcome
func crewLeavePlan(crew: Crew, members: [CrewMember], leavingID: String) -> CrewLeavePlan {
    let others = members.filter { $0.id != leavingID }
    if crew.memberCount <= 1 || others.isEmpty { return .deleteCrew }
    guard crew.ownerID == leavingID else { return .leave(newOwnerID: nil) }
    let nextOwner = others.sorted { first, second in
        first.joinedAt != second.joinedAt ? first.joinedAt < second.joinedAt : first.id < second.id
    }.first
    return .leave(newOwnerID: nextOwner?.id)
}

func leaveCrewMessage(plan: CrewLeavePlan, members: [CrewMember]) -> String {
    switch plan {
    case .deleteCrew:
        return "You're the last member, so the crew and its invite code are deleted."
    case .leave(let newOwnerID):
        if let newOwnerID, let owner = members.first(where: { $0.id == newOwnerID }) {
            return "\(owner.displayName) will look after the crew. You can join again with the invite code."
        }
        return "You can join again with the invite code."
    }
}

func canRemoveCrewMember(_ memberID: String, currentUserID: String, crew: Crew) -> Bool {
    crew.ownerID == currentUserID && memberID != currentUserID
}

func crewMemberCountText(_ count: Int) -> String {
    "\(count) of \(maximumCrewMembers) members"
}

func crewMemberRole(_ member: CrewMember, crew: Crew, currentUserID: String) -> String {
    let isYou = member.id == currentUserID
    let isOwner = member.id == crew.ownerID
    switch (isYou, isOwner) {
    case (true, true): return "You · started the crew"
    case (true, false): return "You"
    case (false, true): return "Started the crew"
    case (false, false): return "Member"
    }
}

func crewInviteShareText(_ crew: Crew) -> String {
    "Join my crew \(crew.name) on Aura. Open the Crew tab and enter the code \(crew.inviteCode)."
}

func removedFromCrewMessage(crewName: String?) -> String {
    if let crewName { return "You're no longer in \(crewName)." }
    return "You're no longer in that crew."
}

// Map Firestore fields
func crew(id: String, fields: [String: Any]) -> Crew? {
    guard let name = fields["name"] as? String,
          let inviteCode = fields["inviteCode"] as? String,
          let ownerID = fields["ownerID"] as? String else { return nil }
    let memberCount = (fields["memberCount"] as? NSNumber)?.intValue ?? 0
    return Crew(id: id, name: name, inviteCode: inviteCode, ownerID: ownerID, memberCount: memberCount)
}

func crewMember(id: String, fields: [String: Any]) -> CrewMember? {
    guard let displayName = fields["displayName"] as? String else { return nil }
    let avatar = AvatarPreset(rawValue: fields["avatarPreset"] as? String ?? "") ?? .magenta
    let joinedAt = fields["joinedAt"] as? Date ?? .distantPast
    return CrewMember(
        id: id,
        displayName: displayName,
        avatarPreset: avatar,
        joinedAt: joinedAt,
        showOnRankings: fields["showOnRankings"] as? Bool ?? false,
        lifetimeXP: (fields["lifetimeXP"] as? NSNumber)?.intValue ?? 0,
        weekStartDay: (fields["weekStartDay"] as? NSNumber)?.intValue ?? 0,
        weekDiscoveries: (fields["weekDiscoveries"] as? NSNumber)?.intValue ?? 0
    )
}

func crewInvite(code: String, fields: [String: Any]) -> CrewInvite? {
    guard let crewID = fields["crewID"] as? String,
          let crewName = fields["crewName"] as? String else { return nil }
    return CrewInvite(code: code, crewID: crewID, crewName: crewName)
}

// Weekly goal
func currentWeekStart(now: Date) -> Int {
    weekStartDay(forDay: dayNumber(for: now))
}

func weeklyWalls(of member: CrewMember, weekStart: Int) -> Int {
    guard member.showOnRankings, member.weekStartDay == weekStart else { return 0 }
    return max(0, member.weekDiscoveries)
}

// Ranking order
func rankedCrewMembers(_ members: [CrewMember]) -> [CrewRanking] {
    let sorted = members.filter(\.showOnRankings).sorted { first, second in
        if first.lifetimeXP != second.lifetimeXP { return first.lifetimeXP > second.lifetimeXP }
        if first.joinedAt != second.joinedAt { return first.joinedAt < second.joinedAt }
        return first.id < second.id
    }
    return sorted.enumerated().map { CrewRanking(rank: $0.offset + 1, member: $0.element) }
}

func crewWeeklyGoal(members: [CrewMember]) -> Int {
    members.filter(\.showOnRankings).count * weeklyWallsPerParticipant
}

func crewWeeklyProgress(members: [CrewMember], weekStart: Int) -> Int {
    members.reduce(0) { $0 + weeklyWalls(of: $1, weekStart: weekStart) }
}

func weeklyGoalText(progress: Int, goal: Int) -> String {
    if goal == 0 { return "Turn on rankings to count towards the weekly goal." }
    return "\(progress) of \(goal) walls this week"
}

func weekEndsText(now: Date) -> String {
    let today = dayNumber(for: now)
    let daysLeft = currentWeekStart(now: now) + 7 - today
    if daysLeft <= 1 { return "Ends tonight at midnight" }
    return "\(daysLeft) days left · Monday to Sunday"
}

func rankingScoreText(_ member: CrewMember, weekStart: Int) -> String {
    let walls = weeklyWalls(of: member, weekStart: weekStart)
    let wallsText = walls == 1 ? "1 wall this week" : "\(walls) walls this week"
    return "\(member.lifetimeXP) XP · \(wallsText)"
}

struct RankingScore: Equatable {
    var showOnRankings: Bool
    var lifetimeXP: Int
    var weekStartDay: Int
    var weekDiscoveries: Int
}

// Score to share
func rankingScore(from stats: UserStats, showOnRankings: Bool) -> RankingScore {
    guard showOnRankings else {
        return RankingScore(showOnRankings: false, lifetimeXP: 0, weekStartDay: 0, weekDiscoveries: 0)
    }
    return RankingScore(
        showOnRankings: true,
        lifetimeXP: stats.lifetimeXP,
        weekStartDay: stats.weekStartDay,
        weekDiscoveries: stats.weekDiscoveries
    )
}

// Sync check
func needsScoreSync(member: CrewMember, stats: UserStats) -> Bool {
    guard member.showOnRankings else { return false }
    let wanted = rankingScore(from: stats, showOnRankings: true)
    return member.lifetimeXP != wanted.lifetimeXP
        || member.weekStartDay != wanted.weekStartDay
        || member.weekDiscoveries != wanted.weekDiscoveries
}

let rankingsOffHint = "You're not on the rankings. Turn on \"Show me on crew rankings\" in Me, Settings."

func rankingSettingDetail(isInCrew: Bool) -> String {
    isInCrew ? rankingsExplanation : "Join a crew in the Crew tab to use rankings."
}

let rankingsExplanation = "Shows your XP and walls found this week to this crew only. Turn it off any time and your score disappears."
