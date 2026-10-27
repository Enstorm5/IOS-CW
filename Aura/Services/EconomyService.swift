import Foundation
import FirebaseFirestore

enum QuestClaimOutcome {
    case claimed(UserStats)
    case notReady(String)
}

final class EconomyService {
    private let database = Firestore.firestore()

    private func userDocument(_ userID: String) -> DocumentReference {
        database.collection("users").document(userID)
    }

    func listenToStats(userID: String, onChange: @escaping (UserStats?, Bool) -> Void) -> ListenerRegistration {
        userDocument(userID).addSnapshotListener { snapshot, error in
            onChange(snapshot?.data().map(userStats(fields:)), error != nil)
        }
    }

    func createStatsIfMissing(userID: String) async throws {
        let document = userDocument(userID)
        let snapshot = try await document.getDocument()
        if !snapshot.exists {
            try await document.setData(firestoreFields(for: UserStats()))
        }
    }

    func claimDiscovery(userID: String, wallID: String, now: Date) async throws -> DiscoveryOutcome {
        try await createStatsIfMissing(userID: userID)
        let userReference = userDocument(userID)
        let discoveryReference = userReference.collection("discoveries").document(wallID)
        let today = dayNumber(for: now)

        let result = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                if try transaction.getDocument(discoveryReference).exists {
                    return nil
                }
                let current = userStats(fields: try transaction.getDocument(userReference).data() ?? [:])
                let updated = statsAfterDiscovery(current, wallID: wallID, today: today)
                transaction.setData(firestoreFields(for: updated), forDocument: userReference)
                transaction.setData(["day": today, "createdAt": FieldValue.serverTimestamp()], forDocument: discoveryReference)
                return updated
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        guard let updated = result as? UserStats else { return .alreadyDiscovered }
        return .awarded(updated)
    }

    func claimDailyQuest(userID: String, now: Date) async throws -> QuestClaimOutcome {
        let userReference = userDocument(userID)
        let today = dayNumber(for: now)
        let claimReference = userReference.collection("questClaims").document(dailyQuestClaimID(today: today))

        let result = try await database.runTransaction { transaction, errorPointer -> Any? in
            do {
                let current = userStats(fields: try transaction.getDocument(userReference).data() ?? [:])
                if isDailyQuestClaimed(current, today: today) {
                    return "You've already claimed today's quest."
                }
                guard canClaimDailyQuest(current, today: today) else {
                    return "Discover \(dailyQuestTarget) walls today to claim this quest."
                }
                let updated = statsAfterDailyQuestClaim(current, today: today)
                transaction.setData(firestoreFields(for: updated), forDocument: userReference)
                transaction.setData(["day": today, "createdAt": FieldValue.serverTimestamp()], forDocument: claimReference)
                return updated
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        if let updated = result as? UserStats {
            return .claimed(updated)
        }
        return .notReady(result as? String ?? "Couldn't claim the quest. Try again.")
    }
}
