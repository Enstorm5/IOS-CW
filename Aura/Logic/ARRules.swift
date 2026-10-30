import Foundation
import ARKit

// AR limits
let maximumWorldMapBytes = 20 * 1024 * 1024
let maximumSnapshotBytes = 2 * 1024 * 1024
let relocalizationTimeoutSeconds: TimeInterval = 30

// Mapping states
enum MappingStatus: Equatable {
    case notAvailable
    case limited
    case extending
    case mapped
}

enum TrackingStatus: Equatable {
    case notAvailable
    case initializing
    case relocalizing
    case movingTooFast
    case notEnoughDetail
    case limited
    case normal
}

// Map ARKit status
func mappingStatus(from status: ARFrame.WorldMappingStatus) -> MappingStatus {
    switch status {
    case .notAvailable: .notAvailable
    case .limited: .limited
    case .extending: .extending
    case .mapped: .mapped
    @unknown default: .notAvailable
    }
}

func trackingStatus(from state: ARCamera.TrackingState) -> TrackingStatus {
    switch state {
    case .notAvailable:
        return .notAvailable
    case .normal:
        return .normal
    case .limited(let reason):
        switch reason {
        case .initializing: return .initializing
        case .relocalizing: return .relocalizing
        case .excessiveMotion: return .movingTooFast
        case .insufficientFeatures: return .notEnoughDetail
        default: return .limited
        }
    }
}

// Save gate
func canSaveWorldMap(tracking: TrackingStatus, mapping: MappingStatus, hasWallAnchor: Bool) -> Bool {
    tracking == .normal && mapping == .mapped && hasWallAnchor
}

// Restore gate
func isWallRestored(tracking: TrackingStatus, hasExpectedAnchor: Bool) -> Bool {
    tracking == .normal && hasExpectedAnchor
}

// Restore timeout
func hasRelocalizationTimedOut(startedAt: Date, now: Date, timeoutSeconds: TimeInterval) -> Bool {
    now.timeIntervalSince(startedAt) >= timeoutSeconds
}

// Scan guidance
func mappingGuidance(_ mapping: MappingStatus) -> String {
    switch mapping {
    case .notAvailable: "Point the camera around the area."
    case .limited: "Keep moving slowly. Include nearby objects, not just the wall."
    case .extending: "Almost there. Keep scanning the surroundings."
    case .mapped: "Area mapped. You can save now."
    }
}

func trackingGuidance(_ tracking: TrackingStatus) -> String? {
    switch tracking {
    case .normal: nil
    case .notAvailable: "AR tracking isn't available right now."
    case .initializing: "Starting AR. Move the phone slowly."
    case .relocalizing: "Match the photo and move slowly."
    case .movingTooFast: "Slow down."
    case .notEnoughDetail: "Not enough detail here. Aim at textured surfaces."
    case .limited: "Tracking is limited. Move slowly."
    }
}

func formattedByteCount(_ bytes: Int) -> String {
    String(format: "%.1f MB", Double(bytes) / 1_048_576)
}
