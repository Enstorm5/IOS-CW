import Testing
import Foundation
@testable import Aura

@MainActor
struct CrewRulesTests {
    let crewSample = Crew(id: "c1", name: "Night Owls", inviteCode: "ABC234", ownerID: "owner", memberCount: 3)

    func member(_ id: String, joined seconds: Double) -> CrewMember {
        CrewMember(id: id, displayName: id.capitalized, avatarPreset: .mint, joinedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func crewNameMustBeTwoToThirtyCharacters() {
        #expect(crewNameValidationError("  ") == "Give your crew a name.")
        #expect(crewNameValidationError("A") == "Use at least 2 characters.")
        #expect(crewNameValidationError(String(repeating: "a", count: 31)) == "Use 30 characters or fewer.")
        #expect(crewNameValidationError(" Night Owls ") == nil)
    }

    @Test func inviteCodesAreCleanedAndChecked() {
        #expect(normalizedInviteCode(" abc-234 ") == "ABC234")
        #expect(inviteCodeValidationError("") == "Enter the invite code from your friend.")
        #expect(inviteCodeValidationError("abc23") != nil)
        #expect(inviteCodeValidationError("ABC10O") != nil)
        #expect(inviteCodeValidationError("abc-234") == nil)
    }

    @Test func generatedCodesUseOnlyTheSafeAlphabet() {
        #expect(inviteCode(fromIndexes: [0, 1, 2, 31, 32, -1]) == "ABC9AB")
        for _ in 0..<50 {
            #expect(inviteCodeValidationError(randomInviteCode()) == nil)
        }
    }

    @Test func membersSortOwnerFirstThenByJoinTime() {
        let members = [member("zed", joined: 10), member("owner", joined: 30), member("amy", joined: 10), member("bob", joined: 5)]
        #expect(sortedCrewMembers(members, ownerID: "owner").map(\.id) == ["owner", "bob", "amy", "zed"])
    }

    @Test func lastMemberLeavingDeletesTheCrew() {
        let solo = Crew(id: "c1", name: "Solo", inviteCode: "ABC234", ownerID: "owner", memberCount: 1)
        #expect(crewLeavePlan(crew: solo, members: [member("owner", joined: 1)], leavingID: "owner") == .deleteCrew)
        #expect(crewLeavePlan(crew: crewSample, members: [member("owner", joined: 1)], leavingID: "owner") == .deleteCrew)
    }

    @Test func ownerLeavingHandsOverToTheLongestMember() {
        let members = [member("owner", joined: 1), member("late", joined: 50), member("early", joined: 20)]
        #expect(crewLeavePlan(crew: crewSample, members: members, leavingID: "owner") == .leave(newOwnerID: "early"))
        #expect(crewLeavePlan(crew: crewSample, members: members, leavingID: "late") == .leave(newOwnerID: nil))
        #expect(leaveCrewMessage(plan: .leave(newOwnerID: "early"), members: members) == "Early will look after the crew. You can join again with the invite code.")
        #expect(leaveCrewMessage(plan: .deleteCrew, members: members) == "You're the last member, so the crew and its invite code are deleted.")
    }

    @Test func onlyTheOwnerCanRemoveOthers() {
        #expect(canRemoveCrewMember("amy", currentUserID: "owner", crew: crewSample))
        #expect(!canRemoveCrewMember("owner", currentUserID: "owner", crew: crewSample))
        #expect(!canRemoveCrewMember("bob", currentUserID: "amy", crew: crewSample))
    }

    @Test func rolesAndTexts() {
        #expect(crewMemberRole(member("owner", joined: 1), crew: crewSample, currentUserID: "owner") == "You · started the crew")
        #expect(crewMemberRole(member("owner", joined: 1), crew: crewSample, currentUserID: "amy") == "Started the crew")
        #expect(crewMemberRole(member("amy", joined: 1), crew: crewSample, currentUserID: "amy") == "You")
        #expect(crewMemberRole(member("bob", joined: 1), crew: crewSample, currentUserID: "amy") == "Member")
        #expect(crewMemberCountText(3) == "3 of 20 members")
        #expect(crewInviteShareText(crewSample).contains("ABC234"))
        #expect(removedFromCrewMessage(crewName: "Night Owls") == "You're no longer in Night Owls.")
        #expect(removedFromCrewMessage(crewName: nil) == "You're no longer in that crew.")
    }

    @Test func firestoreMapping() {
        let mapped = crew(id: "c1", fields: ["name": "Night Owls", "inviteCode": "ABC234", "ownerID": "owner", "memberCount": 3])
        #expect(mapped == crewSample)
        #expect(crew(id: "c1", fields: ["name": "x"]) == nil)

        let joined = Date(timeIntervalSince1970: 100)
        let mappedMember = crewMember(id: "amy", fields: ["displayName": "Amy", "avatarPreset": "night", "joinedAt": joined])
        #expect(mappedMember == CrewMember(id: "amy", displayName: "Amy", avatarPreset: .night, joinedAt: joined))
        #expect(crewMember(id: "amy", fields: ["displayName": "Amy", "avatarPreset": "unknown"])?.avatarPreset == .magenta)

        #expect(crewInvite(code: "ABC234", fields: ["crewID": "c1", "crewName": "Night Owls"]) == CrewInvite(code: "ABC234", crewID: "c1", crewName: "Night Owls"))
        #expect(crewInvite(code: "ABC234", fields: [:]) == nil)
    }
}
