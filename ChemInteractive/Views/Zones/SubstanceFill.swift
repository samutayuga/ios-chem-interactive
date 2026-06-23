import SwiftUI
import ChemCore

/// The physical state a dropped substance is shown in.
enum SubstanceState { case solid, liquid, gas, aqueous }

/// Resolve the state for a filled zone: polyatomic ions are aqueous; elements
/// use their stored standard state; unknown symbols fall back to liquid.
func resolveSubstanceState(for zone: ZoneState, elements: [Element]) -> SubstanceState {
    if zone.isPolyatomic { return .aqueous }
    guard let el = elements.first(where: { $0.symbol == zone.symbol }) else { return .liquid }
    switch el.raw.state {
    case .solid:  return .solid
    case .liquid: return .liquid
    case .gas:    return .gas
    }
}

/// State-appropriate animated fill for the measuring cylinder, clipped to its
/// shape. Entrance animations are one-shot; gas bubbles loop.
struct SubstanceFill: View {
    let state: SubstanceState
    let color: Color
    let fill: CGFloat

    @State private var appeared = false

    var body: some View {
        layer
            .clipShape(PotionFlaskShape())
            .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
    }

    @ViewBuilder private var layer: some View {
        switch state {
        case .liquid:  liquidLayer
        case .aqueous: aqueousLayer
        case .solid:   solidLayer
        case .gas:     gasLayer
        }
    }

    private var liquidLayer: some View {
        WaveTop(fill: appeared ? fill : 0).fill(color.opacity(0.55))
    }

    private var aqueousLayer: some View {
        ZStack {
            WaveTop(fill: appeared ? fill : 0).fill(color.opacity(0.55))
            GeometryReader { geo in
                let xs: [CGFloat] = [0.3, 0.5, 0.7, 0.4, 0.6]
                let ys: [CGFloat] = [0.55, 0.5, 0.6, 0.65, 0.45]
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(color.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .position(x: geo.size.width * xs[i], y: geo.size.height * ys[i])
                        .scaleEffect(appeared ? 2.2 : 0.4)
                        .opacity(appeared ? 0 : 0.8)
                }
            }
        }
    }

    private var solidLayer: some View {
        GeometryReader { geo in
            let h = geo.size.height
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.7))
                .frame(height: h * fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .offset(y: appeared ? 0 : -h)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)
        }
    }

    private var gasLayer: some View {
        ZStack {
            color.opacity(0.12)
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let n = 10
                    for i in 0..<n {
                        let period = 2.5 + Double(i % 3) * 0.7
                        let phase = (t / period + Double(i) * 0.13).truncatingRemainder(dividingBy: 1)
                        let x = size.width * (0.15 + 0.7 * Double((i * 37) % 100) / 100.0)
                        let y = size.height * (1 - phase)   // rise bottom → top
                        let r = 2.0 + Double(i % 3)
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                 with: .color(color.opacity(0.5)))
                    }
                }
            }
        }
    }
}
