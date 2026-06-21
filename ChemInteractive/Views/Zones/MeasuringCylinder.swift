import SwiftUI

/// A graduated measuring cylinder: narrow vertical body, a small pour-spout at
/// the top-right rim, and a wider rounded base foot. Scales to `rect`.
struct MeasuringCylinderShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let bodyLeft = x + w * 0.15
        let bodyRight = x + w * 0.85
        let footLeft = x + w * 0.07
        let footRight = x + w * 0.93
        let rimY = y + h * 0.05
        let spout = w * 0.10
        let footTopY = y + h * 0.90
        let bottomY = y + h
        let corner = w * 0.06

        // Rim left→right with a pour-spout on the right.
        p.move(to: CGPoint(x: bodyLeft, y: rimY))
        p.addLine(to: CGPoint(x: bodyRight - spout, y: rimY))
        p.addLine(to: CGPoint(x: bodyRight + spout * 0.4, y: y))   // spout tip up/out
        p.addLine(to: CGPoint(x: bodyRight, y: rimY + h * 0.02))   // back to wall

        // Right wall down, flare out to the foot, rounded bottom-right.
        p.addLine(to: CGPoint(x: bodyRight, y: footTopY))
        p.addLine(to: CGPoint(x: footRight, y: footTopY))
        p.addLine(to: CGPoint(x: footRight, y: bottomY - corner))
        p.addQuadCurve(to: CGPoint(x: footRight - corner, y: bottomY),
                       control: CGPoint(x: footRight, y: bottomY))

        // Base, rounded bottom-left.
        p.addLine(to: CGPoint(x: footLeft + corner, y: bottomY))
        p.addQuadCurve(to: CGPoint(x: footLeft, y: bottomY - corner),
                       control: CGPoint(x: footLeft, y: bottomY))

        // Left foot up, in to the body wall, up to the rim.
        p.addLine(to: CGPoint(x: footLeft, y: footTopY))
        p.addLine(to: CGPoint(x: bodyLeft, y: footTopY))
        p.addLine(to: CGPoint(x: bodyLeft, y: rimY))
        p.closeSubpath()
        return p
    }
}

/// Measuring graduations: horizontal tick lines up the left inner wall.
/// Minor ticks every 1/8 of the scale height, longer major ticks every 1/4.
/// Returns an open (strokable) path of line segments.
struct GraduationTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let x = rect.minX, y = rect.minY
        let tickLeft = x + w * 0.15       // aligns with the body's left wall
        let minorLen = w * 0.18
        let majorLen = w * 0.32
        let topY = y + h * 0.14
        let botY = y + h * 0.86
        let span = botY - topY
        let divisions = 8
        for i in 0...divisions {
            let ty = topY + span * CGFloat(i) / CGFloat(divisions)
            let len = (i % 2 == 0) ? majorLen : minorLen   // majors every 1/4
            p.move(to: CGPoint(x: tickLeft, y: ty))
            p.addLine(to: CGPoint(x: tickLeft + len, y: ty))
        }
        return p
    }
}

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
