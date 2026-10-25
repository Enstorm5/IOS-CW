import Testing
import Foundation
@testable import Aura

@MainActor
struct MessageRulesTests {

    @Test func validationTrimsAndChecksLength() {
        #expect(messageValidationError("   ") != nil)
        #expect(messageValidationError("  hi  ") == nil)
        #expect(messageValidationError(String(repeating: "a", count: maximumMessageLength)) == nil)
        #expect(messageValidationError(String(repeating: "a", count: maximumMessageLength + 1)) != nil)
    }

    @Test func characterCountIgnoresSurroundingSpaces() {
        #expect(characterCountText("  hey ") == "3/\(maximumMessageLength)")
        #expect(!isOverMessageLength(String(repeating: "a", count: maximumMessageLength)))
        #expect(isOverMessageLength(String(repeating: "a", count: maximumMessageLength + 1)))
    }

    @Test func placementIsStableAndInsideTheMargins() {
        let first = messagePlacement(forMessageID: "message-1")
        let again = messagePlacement(forMessageID: "message-1")
        #expect(first == again)

        for index in 0..<200 {
            let placement = messagePlacement(forMessageID: "message-\(index)")
            #expect(placement.x >= messagePlacementMargin && placement.x <= 1 - messagePlacementMargin)
            #expect(placement.y >= messagePlacementMargin && placement.y <= 1 - messagePlacementMargin)
        }
    }

    @Test func retryWithSameContentReusesTheID() {
        let previous = PendingPost(id: "abc", text: "hi", color: .mint)
        #expect(messageIDForPost(text: "hi", color: .mint, previous: previous) { "new" } == "abc")
        #expect(messageIDForPost(text: "hello", color: .mint, previous: previous) { "new" } == "new")
        #expect(messageIDForPost(text: "hi", color: .ink, previous: previous) { "new" } == "new")
        #expect(messageIDForPost(text: "hi", color: .mint, previous: nil) { "new" } == "new")
    }

    @Test func postingNeedsAFreshFixWithinRadius() {
        let wall = Coordinate(latitude: 6.9130, longitude: 79.8610)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let staleFix = LocationFix(coordinate: wall, horizontalAccuracyMeters: 5, timestamp: now.addingTimeInterval(-16))
        let freshFix = LocationFix(coordinate: wall, horizontalAccuracyMeters: 5, timestamp: now.addingTimeInterval(-2))
        let access = LocationAccess.allowed(isPrecise: true)

        let stale = wallProximity(wallCoordinate: wall, access: access, fix: staleFix, policy: wallPostingPolicy, now: now)
        let fresh = wallProximity(wallCoordinate: wall, access: access, fix: freshFix, policy: wallPostingPolicy, now: now)
        #expect(postingBlockedMessage(for: stale, policy: wallPostingPolicy) != nil)
        #expect(postingBlockedMessage(for: fresh, policy: wallPostingPolicy) == nil)
        #expect(postingBlockedMessage(for: .tooFar(distanceMeters: 80), policy: wallPostingPolicy) == "Move within 50 m of the wall to post. You're 80 m away.")
    }

    @Test func newMessageFieldsMatchTheRules() {
        let message = NewWallMessage(id: "m1", wallID: "w1", authorID: "a1", authorName: "Mira", text: "hi", color: .ink, normalizedX: 0.2, normalizedY: 0.7)
        let fields = firestoreFields(for: message)
        #expect(Set(fields.keys) == ["authorID", "authorName", "text", "contentType", "color", "sparkCount", "normalizedX", "normalizedY", "moderationStatus"])
        #expect(fields["color"] as? String == "ink")
        #expect(fields["sparkCount"] as? Int == 0)
        #expect(fields["moderationStatus"] as? String == "active")
    }
}
