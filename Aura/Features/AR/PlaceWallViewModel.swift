import Foundation
import UIKit
import Observation

@MainActor @Observable
final class PlaceWallViewModel {
    let arSession = ARSessionService()

    private(set) var isPublishing = false
    private(set) var publishError: String?
    private(set) var publishedTitle: String?

    private let publisher: WallPublishService
    private let locationService: LocationService
    private let currentUser: UserProfile
    private var exportedWall: ExportedWall?

    init(publisher: WallPublishService, locationService: LocationService, currentUser: UserProfile) {
        self.publisher = publisher
        self.locationService = locationService
        self.currentUser = currentUser
    }

    func startPlacing() {
        publishedTitle = nil
        publishError = nil
        exportedWall = nil
        arSession.startPlacing()
    }

    func clearPublishError() {
        publishError = nil
    }

    func finish() {
        publishedTitle = nil
        publishError = nil
        exportedWall = nil
        arSession.finish()
    }

    func publish(title: String) async {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let titleError = wallTitleValidationError(cleanedTitle) {
            publishError = titleError
            return
        }

        isPublishing = true
        publishError = nil

        do {
            let fix = await locationService.freshLocation(timeoutSeconds: freshFixTimeoutSeconds).map(locationFix(from:))
            if let locationError = publishLocationError(access: locationService.access, fix: fix, now: Date()) {
                throw UserFacingError(message: locationError)
            }
            guard let fix else { throw UserFacingError(message: "Waiting for an accurate location fix. Try again in a moment.") }

            let exported = try await exportedWallForCurrentPlacement()
            let draft = NewWallDraft(
                wallID: exported.wallID,
                ownerID: currentUser.id,
                title: cleanedTitle,
                coordinate: fix.coordinate,
                size: arSession.wallSize,
                mapChunkCount: splitIntoChunks(exported.mapData, chunkSize: mapChunkByteLimit).count,
                mapByteCount: exported.mapData.count,
                mapChecksum: sha256Hex(exported.mapData),
                captureOSVersion: UIDevice.current.systemVersion
            )

            try await publisher.publish(draft, mapData: exported.mapData)
            try? arSession.saveLocally(ExportedWall(wallID: exported.wallID, mapData: exported.mapData, snapshotData: exported.snapshotData, size: draft.size))
            arSession.finish()
            exportedWall = nil
            publishedTitle = cleanedTitle
        } catch let error as UserFacingError {
            publishError = error.message
        } catch {
            publishError = wallMapErrorMessage(error)
        }
        isPublishing = false
    }

    private func exportedWallForCurrentPlacement() async throws -> ExportedWall {
        if let exportedWall, exportedWall.wallID == arSession.currentWallID {
            return exportedWall
        }
        let exported = try await arSession.exportPlacedWall()
        exportedWall = exported
        return exported
    }
}
