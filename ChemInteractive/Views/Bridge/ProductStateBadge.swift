import SwiftUI
import ChemCore

/// A small pill under a result's compound name showing the product's (heuristic)
/// standard‑state physical form: solid / liquid / gas. Chemistry comes from
/// `ChemCore.predictProductState`; this view only renders it. The state is shown as a
/// tiny kinetic‑theory particle animation rather than a static icon.
struct ProductStateBadge: View {
    let state: ProductState

    private var tint: Color {
        switch state {
        case .solid:  return Theme.accent
        case .liquid: return Theme.anion
        case .gas:    return Theme.cation
        }
    }

    private var label: String {
        switch state {
        case .solid:  return "Solid"
        case .liquid: return "Liquid"
        case .gas:    return "Gas"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            StateParticles(state: state, color: tint)
                .frame(width: 28, height: 18)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("State at standard conditions: \(label)")
    }
}

/// Kinetic‑theory particle motion for a state of matter, drawn in a tiny canvas:
/// - **solid**: a fixed lattice, particles vibrating in place,
/// - **liquid**: particles packed low, sliding/flowing past each other,
/// - **gas**: few particles bouncing freely across the whole area.
/// Motion is time‑driven (deterministic, no animation state).
struct StateParticles: View {
    let state: ProductState
    var color: Color

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                let w = size.width, h = size.height
                let r: CGFloat = 2.0

                func dot(_ x: CGFloat, _ y: CGFloat, _ op: Double = 1) {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(op)))
                }

                switch state {
                case .solid:
                    // 2×3 lattice, each particle jitters with a small per‑cell phase.
                    let cols = 3, rows = 2
                    for c in 0..<cols {
                        for rIdx in 0..<rows {
                            let bx = w * (0.25 + 0.25 * CGFloat(c))
                            let by = h * (0.34 + 0.32 * CGFloat(rIdx))
                            let ph = Double(c * 2 + rIdx)
                            let jx = CGFloat(sin(t * 9 + ph)) * 0.9
                            let jy = CGFloat(cos(t * 11 + ph * 1.3)) * 0.9
                            dot(bx + jx, by + jy)
                        }
                    }
                case .liquid:
                    // Particles packed in the lower half, drifting horizontally with a wave.
                    let n = 5
                    for i in 0..<n {
                        let phase = (t * 0.5 + Double(i) * 0.3).truncatingRemainder(dividingBy: 1)
                        let x = w * CGFloat(phase)
                        let y = h * 0.62 + CGFloat(sin(t * 3 + Double(i))) * h * 0.14
                        dot(x, y)
                    }
                case .gas:
                    // Few particles bouncing across the full area (triangle‑wave paths).
                    let n = 4
                    for i in 0..<n {
                        let sx = 0.7 + Double(i % 3) * 0.25
                        let sy = 0.9 + Double(i % 2) * 0.4
                        func bounce(_ speed: Double, _ off: Double) -> CGFloat {
                            let p = (t * speed + off).truncatingRemainder(dividingBy: 2)
                            return CGFloat(p < 1 ? p : 2 - p)   // 0→1→0
                        }
                        let x = w * (0.1 + 0.8 * bounce(sx, Double(i) * 0.37))
                        let y = h * (0.1 + 0.8 * bounce(sy, Double(i) * 0.61))
                        dot(x, y)
                    }
                }
            }
        }
    }
}
