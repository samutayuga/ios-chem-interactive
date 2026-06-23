import SwiftUI

/// A round-bottom potion flask: a slender neck with a small rim lip flaring into a
/// bulbous body. Scales to `rect`. Used as the drop-zone vessel (outline, fill clip,
/// and hit-test shape).
struct PotionFlaskShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let cx = x + w * 0.5

        let lipHalf = w * 0.16            // widened rim lip
        let neckHalf = w * 0.11           // neck wall half-width
        let lipTopY = y + h * 0.03
        let rimY = y + h * 0.07
        let neckBottomY = y + h * 0.40
        let bulbCenterY = y + h * 0.66
        let bulbRx = w * 0.40
        let bulbRy = h * 0.30
        let bottomY = y + h * 0.97

        // Lip + left neck wall down.
        p.move(to: CGPoint(x: cx - lipHalf, y: lipTopY))
        p.addLine(to: CGPoint(x: cx - neckHalf, y: rimY))
        p.addLine(to: CGPoint(x: cx - neckHalf, y: neckBottomY))

        // Flare into the bulb (left), around the rounded bottom, up the right side.
        p.addCurve(to: CGPoint(x: cx - bulbRx, y: bulbCenterY),
                   control1: CGPoint(x: cx - neckHalf, y: neckBottomY + h * 0.07),
                   control2: CGPoint(x: cx - bulbRx, y: bulbCenterY - bulbRy))
        p.addCurve(to: CGPoint(x: cx, y: bottomY),
                   control1: CGPoint(x: cx - bulbRx, y: bulbCenterY + bulbRy),
                   control2: CGPoint(x: cx - bulbRx * 0.5, y: bottomY))
        p.addCurve(to: CGPoint(x: cx + bulbRx, y: bulbCenterY),
                   control1: CGPoint(x: cx + bulbRx * 0.5, y: bottomY),
                   control2: CGPoint(x: cx + bulbRx, y: bulbCenterY + bulbRy))
        p.addCurve(to: CGPoint(x: cx + neckHalf, y: neckBottomY),
                   control1: CGPoint(x: cx + bulbRx, y: bulbCenterY - bulbRy),
                   control2: CGPoint(x: cx + neckHalf, y: neckBottomY + h * 0.07))

        // Right neck wall up + lip.
        p.addLine(to: CGPoint(x: cx + neckHalf, y: rimY))
        p.addLine(to: CGPoint(x: cx + lipHalf, y: lipTopY))
        p.closeSubpath()
        return p
    }
}

/// Continuously rising bubbles inside the flask bulb — the "bubbling potion" effect.
/// Pure time-driven motion (no animation state), tinted by `color`. Clip to the flask.
struct PotionBubbles: View {
    var color: Color

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let n = 7
                for i in 0..<n {
                    let period = 3.0 + Double(i % 4) * 0.6
                    let phase = (t / period + Double(i) * 0.17).truncatingRemainder(dividingBy: 1)
                    // x scattered across the bulb width; gentle horizontal sway.
                    let baseX = 0.32 + 0.36 * Double((i * 53) % 100) / 100.0
                    let sway = 0.03 * sin(t * 1.3 + Double(i))
                    let x = size.width * (baseX + sway)
                    // rise through the bulb: bottom (0.95) → upper bulb (0.45).
                    let y = size.height * (0.95 - 0.50 * phase)
                    let r = 1.6 + Double(i % 3)
                    let fade = 0.45 * (1 - phase)   // bubbles thin out as they rise
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(fade)))
                }
            }
        }
    }
}
