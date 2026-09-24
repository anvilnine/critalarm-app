import SwiftUI

/// The five faces from `lib/design/faces/face_state.dart`, drawn small enough
/// for a lock-screen card and a Dynamic Island.
///
/// This is the widget-extension copy. It only has to match the Dart painter
/// closely enough to read as the same character at 28-44 pt; the full painter
/// stays in Dart.
enum CritAlarmFace: String {
    case calm, watching, worried, alarmed, acked

    static func forIncident(_ state: IncidentActivityState) -> CritAlarmFace {
        switch state {
        case .open: return .alarmed
        case .acked: return .acked
        case .closed: return .calm
        case .expired: return .worried
        }
    }

    var canvas: Color {
        switch self {
        case .calm, .watching: return CritAlarmPalette.yellow
        case .worried: return CritAlarmPalette.high
        case .alarmed: return CritAlarmPalette.crit
        case .acked: return CritAlarmPalette.cobalt
        }
    }

    var stroke: Color {
        self == .acked ? CritAlarmPalette.onHighlight : CritAlarmPalette.ink
    }
}

/// Tokens copied from `lib/design/tokens/colors.dart` (light palette).
enum CritAlarmPalette {
    static let ink = Color(red: 0.102, green: 0.078, blue: 0.059)      // #1A140F
    static let yellow = Color(red: 1.0, green: 0.788, blue: 0.235)     // #FFC93C
    static let high = Color(red: 1.0, green: 0.541, blue: 0.122)       // #FF8A1F
    static let crit = Color(red: 0.961, green: 0.278, blue: 0.227)     // #F5473A
    static let cobalt = Color(red: 0.165, green: 0.231, blue: 0.847)   // #2A3BD8
    static let onHighlight = Color.white
    static let cream = Color(red: 0.969, green: 0.949, blue: 0.914)    // #F7F2E9
}

struct FaceView: View {
    let face: CritAlarmFace
    var size: CGFloat = 40

    /// Tinted and clear home screens and the lock screen keep only how bright
    /// a colour is, so the coloured square would turn into a flat blob and
    /// the dark ink would vanish. There the face is drawn as light lines on
    /// a faint square instead.
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var fullColor: Bool { renderingMode == .fullColor }
    private var featureColor: Color { fullColor ? face.stroke : .white }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(fullColor ? face.canvas : Color.white.opacity(0.18))
            Canvas { context, canvasSize in
                draw(in: &context, size: canvasSize)
            }
            .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(fullColor ? CritAlarmPalette.ink : Color.white, lineWidth: max(1.5, size * 0.05))
        )
        .accessibilityLabel(Text(face.rawValue))
    }

    private func draw(in context: inout GraphicsContext, size canvas: CGSize) {
        let w = canvas.width
        let h = canvas.height
        let lineWidth = max(2, w * 0.09)
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        let eyeY = h * 0.36
        let leftX = w * 0.28
        let rightX = w * 0.72

        // Eyes.
        switch face {
        case .acked:
            // Closed arches.
            for x in [leftX, rightX] {
                var path = Path()
                path.move(to: CGPoint(x: x - w * 0.12, y: eyeY))
                path.addQuadCurve(
                    to: CGPoint(x: x + w * 0.12, y: eyeY),
                    control: CGPoint(x: x, y: eyeY - h * 0.14)
                )
                context.stroke(path, with: .color(featureColor), style: style)
            }
        case .alarmed:
            for x in [leftX, rightX] {
                let r = w * 0.13
                let rect = CGRect(x: x - r, y: eyeY - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(featureColor), style: style)
            }
        default:
            for x in [leftX, rightX] {
                let r = w * 0.085
                let rect = CGRect(x: x - r, y: eyeY - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(featureColor))
            }
        }

        // Brows, only where the state has them.
        if face == .worried || face == .alarmed {
            let lift = face == .alarmed ? h * 0.10 : h * 0.07
            for (x, inward) in [(leftX, 1.0), (rightX, -1.0)] {
                var path = Path()
                path.move(to: CGPoint(x: x - w * 0.13 * inward, y: eyeY - h * 0.22))
                path.addLine(to: CGPoint(x: x + w * 0.13 * inward, y: eyeY - h * 0.22 + lift))
                context.stroke(path, with: .color(featureColor), style: style)
            }
        }

        // Mouth.
        let mouthY = h * 0.72
        var mouth = Path()
        switch face {
        case .alarmed:
            let rect = CGRect(x: w * 0.34, y: mouthY - h * 0.10, width: w * 0.32, height: h * 0.22)
            mouth.addEllipse(in: rect)
            context.fill(mouth, with: .color(featureColor))
        case .worried:
            mouth.move(to: CGPoint(x: w * 0.32, y: mouthY + h * 0.04))
            mouth.addCurve(
                to: CGPoint(x: w * 0.68, y: mouthY + h * 0.04),
                control1: CGPoint(x: w * 0.44, y: mouthY - h * 0.08),
                control2: CGPoint(x: w * 0.56, y: mouthY + h * 0.12)
            )
            context.stroke(mouth, with: .color(featureColor), style: style)
        default:
            mouth.move(to: CGPoint(x: w * 0.34, y: mouthY - h * 0.02))
            mouth.addQuadCurve(
                to: CGPoint(x: w * 0.66, y: mouthY - h * 0.02),
                control: CGPoint(x: w * 0.5, y: mouthY + h * 0.12)
            )
            context.stroke(mouth, with: .color(featureColor), style: style)
        }
    }
}
