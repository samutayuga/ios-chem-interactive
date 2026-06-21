import SwiftUI
import ChemCore

private func chargeSuperscript(_ n: Int) -> String {
    let a = abs(n); let sign = n > 0 ? "+" : "−"
    return a == 1 ? sign : "\(a)\(sign)"
}

/// An atom circle with Lewis dots, optional charge, optional [ ] brackets.
private struct AtomCircleView: View {
    let symbol: String
    let dots: Int
    var charge: Int? = nil
    var bracketed: Bool = false
    let color: Color

    var body: some View {
        let r: CGFloat = 20
        let w: CGFloat = bracketed ? 84 : 60
        ZStack {
            Circle().fill(color.opacity(0.08))
                .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1.5))
                .frame(width: r * 2, height: r * 2)
            Text(symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            ForEach(Array(dotPositions(dots).enumerated()), id: \.offset) { _, off in
                Circle().fill(color.opacity(0.85)).frame(width: 5, height: 5).offset(x: off.dx, y: off.dy)
            }
            if bracketed {
                HStack {
                    Text("[").font(.system(size: 24, weight: .ultraLight, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Text("]").font(.system(size: 24, weight: .ultraLight, design: .monospaced)).foregroundStyle(.white.opacity(0.55))
                }
                .frame(width: w)
            }
            if let c = charge, c != 0 {
                Text(chargeSuperscript(c)).font(.system(size: 9)).foregroundStyle(color)
                    .offset(x: bracketed ? w / 2 - 2 : r + 8, y: -r - 2)
            }
        }
        .frame(width: w, height: 60)
    }
}

struct BondingDiagramView: View {
    let cation: ZoneState
    let anion: ZoneState

    var body: some View {
        let pair = ionicPair(cation, anion)
        if !pair.cation.isPolyatomic && !pair.anion.isPolyatomic {
            lewisTransferView(pair.cation, pair.anion)
        } else {
            simpleIonView(pair.cation, pair.anion)
        }
    }

    @ViewBuilder private func coeff(_ n: Int, _ color: Color) -> some View {
        // .fixedSize so the coefficient is never compressed to zero width in the
        // narrow (~1/3-screen) result column.
        if n > 1 { Text("\(n)").font(.system(size: 14, weight: .bold)).foregroundStyle(color).fixedSize() }
    }

    private func lewisTransferView(_ cat: ZoneState, _ an: ZoneState) -> some View {
        let t = lewisTransfer(cation: cat, anion: an)
        return VStack(spacing: 6) {
            Text("BEFORE").font(.system(size: 8)).tracking(2).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 4) {
                AtomCircleView(symbol: cat.symbol, dots: cat.valenceElectrons, color: Theme.cation)
                Text("+").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).fixedSize()
                AtomCircleView(symbol: an.symbol, dots: an.valenceElectrons, color: Theme.anion)
            }
            HStack(spacing: 4) {
                Text("\(t.eMoved)e⁻").font(.system(size: 9)).foregroundStyle(Theme.cation.opacity(0.7))
                Text("→").font(.system(size: 16)).foregroundStyle(.white.opacity(0.85))
            }
            Text("AFTER").font(.system(size: 8)).tracking(2).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 4) {
                coeff(t.cCount, Theme.cation)
                AtomCircleView(symbol: cat.symbol, dots: 0, charge: cat.derivedCharge, color: Theme.cation)
                Text("+").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).fixedSize()
                coeff(t.aCount, Theme.anion)
                AtomCircleView(symbol: an.symbol, dots: t.anionAfterDots, charge: an.derivedCharge, bracketed: true, color: Theme.anion)
            }
            BondTypeLabel(bonding: .ionic, a: cat, b: an)
        }
    }

    private func simpleIonView(_ cat: ZoneState, _ an: ZoneState) -> some View {
        let g = max(1, gcd(abs(cat.derivedCharge ?? 0), abs(an.derivedCharge ?? 0)))
        let cCount = abs(an.derivedCharge ?? 0) / g
        let aCount = abs(cat.derivedCharge ?? 0) / g
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                coeff(cCount, Theme.cation)
                AtomCircleView(symbol: cat.symbol, dots: 0, charge: cat.derivedCharge, color: Theme.cation)
                Text("↔").font(.system(size: 18)).foregroundStyle(.white.opacity(0.85)).fixedSize()
                coeff(aCount, Theme.anion)
                AtomCircleView(symbol: an.symbol, dots: 0, charge: an.derivedCharge, bracketed: true, color: Theme.anion)
            }
            BondTypeLabel(bonding: .ionic, a: cat, b: an)
        }
    }
}

#Preview {
    BondingDiagramView(
        cation: ZoneState(symbol: "Na", elementClass: .metal, isPolyatomic: false, isTransition: false,
                          valenceElectrons: 1, oxidationStates: [1], derivedCharge: 1, status: .ionized),
        anion: ZoneState(symbol: "Cl", elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                         valenceElectrons: 7, oxidationStates: [-1], derivedCharge: -1, status: .ionized)
    )
    .padding(40)
    .background(Theme.bg)
}
