import Foundation
import UIKit
import Observation

@MainActor @Observable
// Place wall state
final class PlaceWallViewModel {
    let arSession = ARSessionService()

    private(set) var isPublishing = false
    private(set) var isCapturing = false
    private(set) var publishError: String?
    private(set) var publishedTitle: String?

    private let publisher: WallPublishService
    private let locationService: LocationService
    private let currentUser: UserProfile
    private let statsStore: StatsStore
    private var exportedWall: ExportedWall?
    private var capturedFix: LocationFix?

    init(publisher: WallPublishService, locationService: LocationService, currentUser: UserProfile, statsStore: StatsStore) {
        self.statsStore = statsStore
        self.publisher = publisher
        self.locationService = locationService
        self.currentUser = currentUser
    }

    func startPlacing() {
        publishedTitle = nil
        publishError = nil
        discardCapture()
        arSession.startPlacing()
    }

    var costMessage: String {
        publishCostMessage(balance: statsStore.stats?.balance ?? 0)
    }

    func finish() {
        publishedTitle = nil
        publishError = nil
        discardCapture()
        arSession.finish()
    }

    // Capture wall
    func captureWall() async -> Bool {
        let balance = statsStore.stats?.balance ?? 0
        guard canAfford(balance: balance, cost: publicWallCost) else {
            publishError = publishCostMessage(balance: balance)
            return false
        }

        isCapturing = true
        publishError = nil
        exportedWall = nil
        capturedFix = nil
        defer { isCapturing = false }

        do {
            let exported = try await arSession.exportPlacedWall()
            let fix = await locationService.freshLocation(timeoutSeconds: freshFixTimeoutSeconds).map(locationFix(from:))
            if let locationError = publishLocationError(access: locationService.access, fix: fix, now: Date()) {
                throw UserFacingError(message: locationError)
            }
            guard let fix else { throw UserFacingError(message: "Waiting for an accurate location fix. Try again in a moment.") }
            exportedWall = exported
            capturedFix = fix
            return true
        } catch let error as UserFacingError {
            publishError = error.message
            return false
        } catch {
            publishError = wallMapErrorMessage(error)
            return false
        }
    }

    // Drop capture
    func discardCapture() {
        exportedWall = nil
        capturedFix = nil
    }

    // Publish flow
    func publish(title: String) async {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let titleError = wallTitleValidationError(cleanedTitle) {
            publishError = titleError
            return
        }
        guard let exported = exportedWall, let fix = capturedFix else {
            publishError = "The wall wasn't captured. Close this and tap Publish wall again."
            return
        }

        let balance = statsStore.stats?.balance ?? 0
        guard canAfford(balance: balance, cost: publicWallCost) else {
            publishError = publishCostMessage(balance: balance)
            return
        }

        isPublishing = true
        publishError = nil

        do {
            let draft = NewWallDraft(
                wallID: exported.wallID,
                ownerID: currentUser.id,
                title: cleanedTitle,
                coordinate: fix.coordinate,
                size: exported.size,
                mapChunkCount: splitIntoChunks(exported.mapData, chunkSize: mapChunkByteLimit).count,
                mapByteCount: exported.mapData.count,
                mapChecksum: sha256Hex(exported.mapData),
                captureOSVersion: UIDevice.current.systemVersion
            )

            try await publisher.publish(draft, mapData: exported.mapData)
            arSession.finish()
            discardCapture()
            publishedTitle = cleanedTitle
        } catch let error as UserFacingError {
            publishError = error.message
        } catch {
            publishError = wallMapErrorMessage(error)
        }
        isPublishing = false
    }
}
