import Foundation
import simd

let wallFrameOpeningWidth: Float = 1.4794
let wallFrameOpeningHeight: Float = 1.3577
let wallFrameOpeningCenterX: Float = -0.00185
let wallFrameOpeningCenterY: Float = 0.03408
let wallFrameBackZ: Float = -0.1715

// Frame to wall axes
let wallFrameOrientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))

struct WallFrameFit: Equatable {
    var scale: SIMD3<Float>
    var translation: SIMD3<Float>
}

// Frame opening fit
func wallFrameFit(for size: WallSize) -> WallFrameFit {
    let scaleX = Float(size.width) / wallFrameOpeningWidth
    let scaleY = Float(size.height) / wallFrameOpeningHeight
    let scaleZ = (scaleX + scaleY) / 2
    return WallFrameFit(
        scale: SIMD3<Float>(scaleX, scaleY, scaleZ),
        translation: SIMD3<Float>(-scaleX * wallFrameOpeningCenterX, -scaleZ * wallFrameBackZ, scaleY * wallFrameOpeningCenterY)
    )
}
