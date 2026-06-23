import SwiftUI

/// The liquid region: fills the lower `fill` fraction of `rect` with a gentle
/// static sine-wave top edge. Clip to a vessel shape to take its contour.
struct WaveTop: Shape {
    var fill: CGFloat   // 0…1, fraction of height from the bottom

    var animatableData: CGFloat {
        get { fill }
        set { fill = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let clamped = min(max(fill, 0), 1)
        let surfaceY = rect.maxY - rect.height * clamped
        let amp = rect.height * 0.03
        let midY = surfaceY + amp

        p.move(to: CGPoint(x: rect.minX, y: midY))
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let xx = rect.minX + rect.width * t
            let yy = surfaceY + amp * sin(t * 2 * .pi)
            p.addLine(to: CGPoint(x: xx, y: yy))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
