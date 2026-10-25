import SwiftUI

struct DrawingView: View {
    let drawing: MessageDrawing
    var currentStroke: DrawingStroke? = nil

    var body: some View {
        Canvas { context, size in
            let strokes = drawing.strokes + (currentStroke.map { [$0] } ?? [])
            for stroke in strokes {
                context.stroke(
                    drawingPath(for: stroke, in: size),
                    with: .color(stroke.color.swatchColor),
                    style: StrokeStyle(lineWidth: stroke.width.fractionOfWidth * size.width, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(Color.auraLilac)
    }
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

struct DrawingPad: View {
    @Binding var drawing: MessageDrawing
    let color: MessageColor
    let width: StrokeWidth

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
                                currentStroke = DrawingStroke(color: color, width: width, points: [point])
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

struct DrawingThumbnail: View {
    let drawing: MessageDrawing

    var body: some View {
        DrawingView(drawing: drawing)
            .aspectRatio(drawingAspectRatio, contentMode: .fit)
            .frame(height: AuraSize.drawingThumbnailHeight)
            .clipShape(.rect(cornerRadius: AuraRadius.swatch))
    }
}
