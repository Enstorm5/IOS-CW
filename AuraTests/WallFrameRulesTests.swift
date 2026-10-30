import Testing
import Foundation
import simd
@testable import Aura

@MainActor
struct WallFrameRulesTests {
    func close(_ a: SIMD3<Float>, _ b: SIMD3<Float>, tolerance: Float = 0.001) -> Bool {
        simd_length(a - b) < tolerance
    }

    @Test func aWallTheSizeOfTheOpeningNeedsNoScaling() {
        let fit = wallFrameFit(for: WallSize(width: Double(wallFrameOpeningWidth), height: Double(wallFrameOpeningHeight)))
        #expect(close(fit.scale, SIMD3<Float>(1, 1, 1)))
    }

    @Test func theOpeningMatchesTheWallAndDepthFollowsTheAverage() {
        let fit = wallFrameFit(for: WallSize(width: 1.2, height: 0.8))
        #expect(abs(fit.scale.x * wallFrameOpeningWidth - 1.2) < 0.001)
        #expect(abs(fit.scale.y * wallFrameOpeningHeight - 0.8) < 0.001)
        #expect(abs(fit.scale.z - (fit.scale.x + fit.scale.y) / 2) < 0.0001)
    }

    @Test func biggerWallsScaleTheFrameUp() {
        let small = wallFrameFit(for: WallSize(width: 1, height: 1))
        let big = wallFrameFit(for: WallSize(width: 2, height: 2))
        #expect(close(big.scale, small.scale * 2))
    }

    @Test func theFrameBackSitsOnTheWallAndItsFrontStandsOut() {
        let fit = wallFrameFit(for: WallSize(width: 1.2, height: 0.8))
        let backInAnchorY = fit.scale.z * wallFrameBackZ + fit.translation.y
        #expect(abs(backInAnchorY) < 0.0001)
        #expect(fit.translation.y > 0)
    }

    @Test func theOpeningCentreLandsOnTheAnchorOrigin() {
        let fit = wallFrameFit(for: WallSize(width: 1.2, height: 0.8))
        let rotated = wallFrameOrientation.act(SIMD3<Float>(fit.scale.x * wallFrameOpeningCenterX, fit.scale.y * wallFrameOpeningCenterY, 0))
        let placed = rotated + fit.translation
        #expect(abs(placed.x) < 0.0001 && abs(placed.z) < 0.0001)
    }

    @Test func theModelFrontFacesOutOfTheWallAndItsTopPointsUp() {
        #expect(close(wallFrameOrientation.act(SIMD3<Float>(0, 0, 1)), SIMD3<Float>(0, 1, 0)))
        #expect(close(wallFrameOrientation.act(SIMD3<Float>(0, 1, 0)), SIMD3<Float>(0, 0, -1)))
        #expect(close(wallFrameOrientation.act(SIMD3<Float>(1, 0, 0)), SIMD3<Float>(1, 0, 0)))
    }
}
