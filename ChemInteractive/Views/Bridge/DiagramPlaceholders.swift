import SwiftUI
import ChemCore

/// Cation/anion ordering shared by the placeholders.
private func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
    if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
        return ca > 0 ? (a, b) : (b, a)
    }
    let aCation = a.elementClass == .metal || a.elementClass == .metalloid
    return aCation ? (a, b) : (b, a)
}

private struct ResetButton: View {
    let action: () -> Void
    var body: some View {
        Button("Reset", action: action)
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay(Capsule().stroke(Theme.muted.opacity(0.6), lineWidth: 1))
    }
}

struct IonicCompletePlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        let pair = ionicPair(slotA, slotB)
        VStack(spacing: 12) {
            Text("Ionic compound").font(.system(size: 11)).foregroundStyle(Theme.muted)
            if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                  anionSymbol: pair.anion.symbol, anionCharge: ac,
                                  anionIsPolyatomic: pair.anion.isPolyatomic))
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            }
            Text("[ Lewis transfer diagram — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}

struct CovalentPlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        // Reuse ChemCore stoichiometry; order symbols by IUPAC convention.
        let aFirst = iupacFirst(slotA.symbol, slotB.symbol)
        let first = aFirst ? slotA : slotB
        let second = aFirst ? slotB : slotA
        let s = calcStoich(veA: first.valenceElectrons, veB: second.valenceElectrons)
        VStack(spacing: 12) {
            Text("Covalent molecule").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text("\(first.symbol)\(s.nA > 1 ? subscriptGlyphs(s.nA) : "")\(second.symbol)\(s.nB > 1 ? subscriptGlyphs(s.nB) : "")")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            Text("bond order \(s.bondOrder)").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Text("[ Lewis structure — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}

struct MetallicPlaceholder: View {
    let slotA: ZoneState
    let slotB: ZoneState
    let onReset: () -> Void

    var body: some View {
        let electrons = metallicElectronCount(veA: slotA.valenceElectrons, veB: slotB.valenceElectrons)
        VStack(spacing: 12) {
            Text("Metallic lattice").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Text(slotA.symbol == slotB.symbol ? slotA.symbol : "\(slotA.symbol)–\(slotB.symbol)")
                .font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            Text("\(electrons) delocalised electrons").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
            Text("[ Electron-sea animation — Plan 3 ]").font(.system(size: 10)).foregroundStyle(Theme.muted.opacity(0.7))
            ResetButton(action: onReset)
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.muted.opacity(0.4), lineWidth: 1))
    }
}
