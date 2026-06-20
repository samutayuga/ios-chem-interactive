import SwiftUI
import ChemCore

struct MetallicSeaView: View {
    let slotA: ZoneState
    let slotB: ZoneState

    private let ionPositions: [CGPoint] = [
        CGPoint(x: 40, y: 36), CGPoint(x: 100, y: 36), CGPoint(x: 160, y: 36),
        CGPoint(x: 40, y: 90), CGPoint(x: 100, y: 90), CGPoint(x: 160, y: 90),
    ]
    private let electronPool: [(x0: CGFloat, y0: CGFloat, dx: CGFloat, dy: CGFloat)] = [
        (70, 18, 55, 38), (130, 15, -48, 52), (22, 58, 82, -18), (178, 52, -72, 28),
        (52, 110, 88, -42), (150, 108, -58, -46), (88, 60, 48, -40), (14, 88, 62, -32),
        (186, 80, -58, -28), (100, 115, -32, -52), (62, 42, 70, 42), (138, 80, -65, -35),
    ]
    private let ionColors = [Color(hex: 0xf97316), Color(hex: 0xfb923c)]
    private let electronColor = Color(hex: 0xfde047)

    var body: some View {
        let symbols = [slotA.symbol, slotB.symbol]
        let homo = slotA.symbol == slotB.symbol
        let electrons = Array(electronPool.prefix(metallicElectronsShown(slotA: slotA, slotB: slotB)))

        return VStack(spacing: 8) {
            Text("METALLIC BOND").font(.system(size: 9)).tracking(2).foregroundStyle(.white.opacity(0.35))
            ZStack {
                ForEach(Array(ionPositions.enumerated()), id: \.offset) { i, pos in
                    let idx = metallicIonIndexPattern[i]
                    let clr = ionColors[idx]
                    ZStack {
                        Circle().fill(clr.opacity(0.12))
                            .overlay(Circle().stroke(clr.opacity(0.4), lineWidth: 1.5)).frame(width: 36, height: 36)
                        Text(symbols[idx]).font(.system(size: 11, weight: .bold)).foregroundStyle(clr)
                        Text("+").font(.system(size: 7)).foregroundStyle(clr.opacity(0.7)).offset(x: 13, y: -10)
                    }
                    .position(pos)
                }
                TimelineView(.animation) { tl in
                    Canvas { ctx, _ in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        for (i, e) in electrons.enumerated() {
                            let period = 3.0 + Double(i % 3) * 0.8
                            let phase = (t / period + Double(i) * 0.12).truncatingRemainder(dividingBy: 1)
                            let s = 0.5 * (1 - cos(phase * 2 * .pi))   // smooth 0→1→0
                            let ex = e.x0 + e.dx * s
                            let ey = e.y0 + e.dy * s * 0.85
                            ctx.fill(Path(ellipseIn: CGRect(x: ex - 4, y: ey - 4, width: 8, height: 8)),
                                     with: .color(electronColor.opacity(0.9)))
                        }
                    }
                }
            }
            .frame(width: 200, height: 126)
            .background(.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.1), lineWidth: 1))

            HStack(spacing: 16) {
                legend(Color(hex: 0xf97316), "Positive metal ion")
                legend(electronColor, "Delocalised e⁻")
            }
            .font(.system(size: 8)).foregroundStyle(.white.opacity(0.5))

            VStack(spacing: 2) {
                Text(homo ? slotA.symbol : "\(slotA.symbol) + \(slotB.symbol)")
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                Text(homo ? "Pure metal · metallic bond" : "Alloy · metallic bond")
                    .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t) }
    }
}

#Preview {
    MetallicSeaView(
        slotA: ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 1, oxidationStates: [], derivedCharge: nil, status: .neutral),
        slotB: ZoneState(symbol: "Mg", elementClass: .metal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 2, oxidationStates: [], derivedCharge: nil, status: .neutral)
    )
    .padding(20)
    .background(Theme.bg)
}
