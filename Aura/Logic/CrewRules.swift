import Foundation

let crewNameLengthRange = 2...30
let maximumCrewMembers = 20
let inviteCodeLength = 6
let inviteCodeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

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

func randomInviteCode() -> String {
    inviteCode(fromIndexes: (0..<inviteCodeLength).map { _ in Int.random(in: 0..<inviteCodeAlphabet.count) })
}

func sortedCrewMembers(_ members: [CrewMember], ownerID: String) -> [CrewMember] {
    members.sorted { first, second in
        if (first.id == ownerID) != (second.id == ownerID) { return first.id == ownerID }
        if first.joinedAt != second.joinedAt { return first.joinedAt < second.joinedAt }
        return first.id < second.id
    }
}

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
    return CrewMember(id: id, displayName: displayName, avatarPreset: avatar, joinedAt: joinedAt)
}

func crewInvite(code: String, fields: [String: Any]) -> CrewInvite? {
    guard let crewID = fields["crewID"] as? String,
          let crewName = fields["crewName"] as? String else { return nil }
    return CrewInvite(code: code, crewID: crewID, crewName: crewName)
}
