import Foundation
import FirebaseFirestore

final class CrewService {
    private let database = Firestore.firestore()

    func listenToMembership(userID: String, onChange: @escaping (String?, Bool) -> Void) -> ListenerRegistration {
        membershipDocument(userID).addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            if let snapshot, snapshot.metadata.hasPendingWrites { return }
            onChange(snapshot?.data()?["crewID"] as? String, error != nil)
        }
    }

    func listenToCrew(crewID: String, onChange: @escaping (Crew?, Bool) -> Void) -> ListenerRegistration {
        crewDocument(crewID).addSnapshotListener { snapshot, error in
            if let snapshot, snapshot.metadata.isFromCache, !snapshot.exists { return }
            let loaded = snapshot.flatMap { document in
                document.data().flatMap { crew(id: document.documentID, fields: $0) }
            }
            onChange(loaded, error != nil)
        }
    }

    func listenToMembers(crewID: String, onChange: @escaping ([CrewMember]?) -> Void) -> ListenerRegistration {
        crewDocument(crewID).collection("members").addSnapshotListener { snapshot, _ in
            let members = snapshot?.documents.compactMap { document in
                crewMember(id: document.documentID, fields: fieldsWithDates(document.data(with: .estimate)))
            }
            onChange(members)
        }
    }

    func findInvite(code: String) async throws -> CrewInvite? {
        let snapshot = try await database.collection("crewInvites").document(code).getDocument()
        return snapshot.data().flatMap { crewInvite(code: code, fields: $0) }
    }

    func createCrew(name: String, profile: UserProfile) async throws {
        let crewReference = database.collection("crews").document()
        var code = randomInviteCode()
        for _ in 0..<5 {
            if try await findInvite(code: code) == nil { break }
            code = randomInviteCode()
        }

        let batch = database.batch()
        batch.setData([
            "name": name,
            "inviteCode": code,
            "ownerID": profile.id,
            "memberCount": 1,
            "lastMemberID": profile.id,
            "createdAt": FieldValue.serverTimestamp(),
        ], forDocument: crewReference)
        batch.setData(memberFields(profile: profile, inviteCode: code), forDocument: crewReference.collection("members").document(profile.id))
        batch.setData(membershipFields(crewID: crewReference.documentID), forDocument: membershipDocument(profile.id))
        batch.setData(["crewID": crewReference.documentID, "crewName": name], forDocument: database.collection("crewInvites").document(code))
        try await batch.commit()
    }

    func joinCrew(_ invite: CrewInvite, profile: UserProfile) async throws {
        let crewReference = crewDocument(invite.crewID)
        let batch = database.batch()
        batch.setData(memberFields(profile: profile, inviteCode: invite.code), forDocument: crewReference.collection("members").document(profile.id))
        batch.setData(membershipFields(crewID: invite.crewID), forDocument: membershipDocument(profile.id))
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(1)),
            "lastMemberID": profile.id,
        ], forDocument: crewReference)
        try await batch.commit()
    }

    func leaveCurrentCrew(userID: String) async throws {
        let membership = try await membershipDocument(userID).getDocument()
        guard let crewID = membership.data()?["crewID"] as? String else { return }

        let crewReference = crewDocument(crewID)
        let memberReference = crewReference.collection("members").document(userID)
        let isStillMember = (try? await memberReference.getDocument().exists) ?? false
        guard isStillMember else {
            try await membershipDocument(userID).delete()
            return
        }

        let crewSnapshot = try await crewReference.getDocument()
        guard let currentCrew = crewSnapshot.data().flatMap({ crew(id: crewID, fields: $0) }) else {
            try await membershipDocument(userID).delete()
            return
        }
        let members = try await crewReference.collection("members").getDocuments().documents.compactMap { document in
            crewMember(id: document.documentID, fields: fieldsWithDates(document.data(with: .estimate)))
        }

        let batch = database.batch()
        batch.deleteDocument(memberReference)
        batch.deleteDocument(membershipDocument(userID))
        switch crewLeavePlan(crew: currentCrew, members: members, leavingID: userID) {
        case .deleteCrew:
            batch.deleteDocument(crewReference)
            batch.deleteDocument(database.collection("crewInvites").document(currentCrew.inviteCode))
        case .leave(let newOwnerID):
            var update: [String: Any] = [
                "memberCount": FieldValue.increment(Int64(-1)),
                "lastMemberID": userID,
            ]
            if let newOwnerID {
                update["ownerID"] = newOwnerID
            }
            batch.updateData(update, forDocument: crewReference)
        }
        try await batch.commit()
    }

    func removeMember(_ memberID: String, crewID: String) async throws {
        let crewReference = crewDocument(crewID)
        let batch = database.batch()
        batch.deleteDocument(crewReference.collection("members").document(memberID))
        batch.updateData([
            "memberCount": FieldValue.increment(Int64(-1)),
            "lastMemberID": memberID,
        ], forDocument: crewReference)
        try await batch.commit()
    }

    func clearMembership(userID: String) async throws {
        try await membershipDocument(userID).delete()
    }

    private func crewDocument(_ crewID: String) -> DocumentReference {
        database.collection("crews").document(crewID)
    }

    private func membershipDocument(_ userID: String) -> DocumentReference {
        database.collection("crewMemberships").document(userID)
    }

    private func memberFields(profile: UserProfile, inviteCode: String) -> [String: Any] {
        [
            "displayName": profile.displayName,
            "avatarPreset": profile.avatarPreset.rawValue,
            "inviteCode": inviteCode,
            "joinedAt": FieldValue.serverTimestamp(),
        ]
    }

    private func membershipFields(crewID: String) -> [String: Any] {
        ["crewID": crewID, "joinedAt": FieldValue.serverTimestamp()]
    }

    private func fieldsWithDates(_ fields: [String: Any]) -> [String: Any] {
        var converted = fields
        for (key, value) in fields {
            if let timestamp = value as? Timestamp {
                converted[key] = timestamp.dateValue()
            }
        }
        return converted
    }
}
