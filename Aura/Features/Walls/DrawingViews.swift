import SwiftUI
import UIKit

// Draw strokes
struct DrawingView: View {
    let drawing: MessageDrawing
    var currentStroke: DrawingStroke? = nil

    var body: some View {
        Canvas { context, size in
            let strokes = drawing.strokes + (currentStroke.map { [$0] } ?? [])
            for stroke in strokes {
                let path = drawingPath(for: stroke, in: size)
                let lineWidth = stroke.width.fractionOfWidth * size.width
                // Neon glow
                if stroke.brush == .neon {
                    for layer in neonGlowLayers {
                        context.stroke(
                            path,
                            with: .color(stroke.color.swatchColor.opacity(layer.opacity)),
                            style: StrokeStyle(lineWidth: lineWidth * layer.widthScale, lineCap: .round, lineJoin: .round)
                        )
                    }
                    context.stroke(
                        path,
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: lineWidth * neonCoreWidthScale, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    context.stroke(
                        path,
                        with: .color(stroke.color.swatchColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .background(Color.auraLilac)
    }
}

// Drawing as image
func drawingCGImage(_ drawing: MessageDrawing, pixelWidth: CGFloat) -> CGImage? {
    let size = CGSize(width: pixelWidth, height: pixelWidth / CGFloat(drawingAspectRatio))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor(Color.auraLilac).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let cgContext = context.cgContext
        cgContext.setLineCap(.round)
        cgContext.setLineJoin(.round)
        for stroke in drawing.strokes {
            let path = drawingPath(for: stroke, in: size).cgPath
            let color = UIColor(stroke.color.swatchColor)
            let lineWidth = stroke.width.fractionOfWidth * size.width
            if stroke.brush == .neon {
                for layer in neonGlowLayers {
                    cgContext.addPath(path)
                    cgContext.setStrokeColor(color.withAlphaComponent(layer.opacity).cgColor)
                    cgContext.setLineWidth(lineWidth * layer.widthScale)
                    cgContext.strokePath()
                }
                cgContext.addPath(path)
                cgContext.setStrokeColor(UIColor.white.cgColor)
                cgContext.setLineWidth(lineWidth * neonCoreWidthScale)
                cgContext.strokePath()
            } else {
                cgContext.addPath(path)
                cgContext.setStrokeColor(color.cgColor)
                cgContext.setLineWidth(lineWidth)
                cgContext.strokePath()
            }
        }
    }
    return image.cgImage
}

func drawingPath(for stroke: DrawingStroke, in size: CGSize) -> Path {
    var path = Path()
    guard let first = stroke.points.first else { return path }
    let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
    path.move(to: start)
    if stroke.points.count == 1 {
        path.addLine(to: start)
    }
    for point in stroke.points.dropFirst() {
        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
    }
    return path
}

// Finger drawing
struct DrawingPad: View {
    @Binding var drawing: MessageDrawing
    let color: MessageColor
    let width: StrokeWidth
    var brush: StrokeBrush = .marker

    @State private var currentStroke: DrawingStroke?

    var body: some View {
        GeometryReader { geometry in
            DrawingView(drawing: drawing, currentStroke: currentStroke)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let point = normalizedDrawingPoint(value.location, in: geometry.size)
                            if let stroke = currentStroke {
                                currentStroke = addingPoint(point, to: stroke)
                            } else {
                                currentStroke = DrawingStroke(color: color, width: width, brush: brush, points: [point])
                            }
                        }
                        .onEnded { _ in
                            if let currentStroke {
                                drawing.strokes.append(currentStroke)
                            }
                            currentStroke = nil
                        }
                )
        }
        .aspectRatio(drawingAspectRatio, contentMode: .fit)
        .clipShape(.rect(cornerRadius: AuraRadius.control))
        .accessibilityElement()
        .accessibilityLabel("Drawing area")
        .accessibilityHint("Draw with one finger.")
    }
}

// Small preview
struct DrawingThumbnail: View {
    let drawing: MessageDrawing

    var body: some View {
        DrawingView(drawing: drawing)
            .aspectRatio(drawingAspectRatio, contentMode: .fit)
            .frame(height: AuraSize.drawingThumbnailHeight)
            .clipShape(.rect(cornerRadius: AuraRadius.swatch))
    }
}
