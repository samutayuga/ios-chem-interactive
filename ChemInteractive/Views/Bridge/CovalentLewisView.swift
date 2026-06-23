import SwiftUI
import ChemCore

struct CovalentLewisView: View {
    let slotA: ZoneState
    let slotB: ZoneState
    @Environment(CanvasModel.self) private var model

    private let lpColor = Color(hex: 0xc8d2ff)
    private let canvas = CGSize(width: 280, height: 220)

    var body: some View {
        let layout = covalentLayout(slotA: slotA, slotB: slotB)
        let central = layout.centralIsA ? slotA : slotB
        let peripheral = layout.centralIsA ? slotB : slotA
        let centralColor = layout.centralIsA ? Theme.cation : Theme.anion
        let peripheralColor = layout.centralIsA ? Theme.anion : Theme.cation

        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let rC: CGFloat = 38
        let rP: CGFloat = layout.nPeripheral == 1 ? 34 : 28
        let dCP = rC + rP - 14
        let positions = peripheralPositions(layout.nPeripheral, center: center, distance: dCP)
        let centralBondAngles = positions.map { atan2(Double($0.y - center.y), Double($0.x - center.x)) }

        return VStack(spacing: 8) {
            BondTypeLabel(bonding: .covalent, a: slotA, b: slotB)
            formula(layout.bondOrder)
            ZStack {
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    bond(from: center, to: p)
                    sharedPairs(from: center, to: p, order: layout.bondOrder,
                                c1: centralColor, c2: peripheralColor)
                }
                ForEach(Array(positions.enumerated()), id: \.offset) { _, p in
                    atom(peripheral.symbol, color: peripheralColor, r: rP).position(p)
                    let bondFromP = atan2(Double(center.y - p.y), Double(center.x - p.x))
                    ForEach(Array(lonePairAngles(bondAngles: [bondFromP], count: layout.peripheralLone).enumerated()), id: \.offset) { _, a in
                        lonePair(at: p, angle: a, r: rP)
                    }
                }
                atom(central.symbol, color: centralColor, r: rC).position(center)
                ForEach(Array(lonePairAngles(bondAngles: centralBondAngles, count: layout.centralLone).enumerated()), id: \.offset) { _, a in
                    lonePair(at: center, angle: a, r: rC)
                }
                if layout.nPeripheral > 1 {
                    Text("×\(layout.nPeripheral)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.7))
                        .position(x: canvas.width - 18, y: 14)
                }
            }
            .frame(width: canvas.width, height: canvas.height)
        }
    }

    private func bond(from a: CGPoint, to b: CGPoint) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }.stroke(.white.opacity(0.4), lineWidth: 1)
    }

    @ViewBuilder
    private func sharedPairs(from a: CGPoint, to b: CGPoint, order: Int, c1: Color, c2: Color) -> some View {
        let ang = atan2(b.y - a.y, b.x - a.x)
        let nx = -sin(ang) * 3, ny = cos(ang) * 3
        ForEach(0..<order, id: \.self) { k in
            let frac = CGFloat(k + 1) / CGFloat(order + 1)
            let bx = a.x + (b.x - a.x) * frac
            let by = a.y + (b.y - a.y) * frac
            Group {
                Circle().fill(c1).frame(width: 5, height: 5).position(x: bx - nx, y: by - ny)
                Circle().fill(c2).frame(width: 5, height: 5).position(x: bx + nx, y: by + ny)
            }
        }
    }

    private func atom(_ symbol: String, color: Color, r: CGFloat) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.10)).overlay(Circle().stroke(color.opacity(0.55), lineWidth: 1.8))
            Text(symbol).font(.system(size: r < 32 ? 11 : 13, weight: .bold)).foregroundStyle(color)
        }
        .frame(width: r * 2, height: r * 2)
    }

    @ViewBuilder
    private func lonePair(at p: CGPoint, angle: Double, r: CGFloat) -> some View {
        let d = r + 9
        let x = p.x + CGFloat(cos(angle)) * d
        let y = p.y + CGFloat(sin(angle)) * d
        let px = CGFloat(-sin(angle)) * 3.2, py = CGFloat(cos(angle)) * 3.2
        Group {
            Circle().fill(lpColor.opacity(0.8)).frame(width: 5, height: 5).position(x: x - px, y: y - py)
            Circle().fill(lpColor.opacity(0.8)).frame(width: 5, height: 5).position(x: x + px, y: y + py)
        }
    }

    private func formula(_ bondOrder: Int) -> some View {
        let s = covalentStoich(veA: slotA.valenceElectrons, groupA: slotA.group, periodA: slotA.period,
                               veB: slotB.valenceElectrons, groupB: slotB.group, periodB: slotB.period)
        let homo = slotA.symbol == slotB.symbol
        let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
        let fst = aFirst ? slotA.symbol : slotB.symbol
        let fstN = aFirst ? s.nA : s.nB
        let snd = aFirst ? slotB.symbol : slotA.symbol
        let sndN = aFirst ? s.nB : s.nA
        let text = homo
            ? "\(slotA.symbol)\((s.nA + s.nB) > 1 ? subscriptGlyphs(s.nA + s.nB) : "")"
            : "\(fst)\(fstN > 1 ? subscriptGlyphs(fstN) : "")\(snd)\(sndN > 1 ? subscriptGlyphs(sndN) : "")"
        let remark = orbitalMismatchRemark(slotA, slotB)
        return VStack(spacing: 2) {
            Text(text).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text(covalentCompoundName(slotA: slotA, slotB: slotB, elements: model.elements))
                .font(.system(size: 14)).foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            ProductStateBadge(state: predictProductState(bonding: .covalent, a: slotA, b: slotB))
            if !remark.isEmpty {
                Text(remark)
                    .font(.system(size: 9)).tracking(1).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            }
        }
    }

    /// Caption shown under the compound name only when two same‑group, different‑period
    /// atoms (Group 16) trigger the orbital‑mismatch rule. Empty otherwise — no caption.
    private func orbitalMismatchRemark(_ a: ZoneState, _ b: ZoneState) -> String {
        guard isOrbitalMismatchDoubleBond(groupA: a.group, periodA: a.period, veA: a.valenceElectrons,
                                          groupB: b.group, periodB: b.period, veB: b.valenceElectrons)
        else { return "" }
        let larger = a.period > b.period ? a : b
        let smaller = a.period > b.period ? b : a
        return "Group \(larger.group) orbital mismatch · \(larger.symbol) central, two \(smaller.symbol)"
    }
}

#Preview {
    CovalentLewisView(
        slotA: ZoneState(symbol: "C", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 4, oxidationStates: [], derivedCharge: nil, status: .neutral),
        slotB: ZoneState(symbol: "O", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 6, oxidationStates: [], derivedCharge: nil, status: .neutral)
    )
    .padding(20)
    .background(Theme.bg)
    .environment(CanvasModel())
}
