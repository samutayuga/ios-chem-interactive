import SwiftUI
import ChemCore

struct ExplanationModalView: View {
    @Environment(CanvasModel.self) private var model

    private var slotA: ZoneState? { model.state.slotA }
    private var slotB: ZoneState? { model.state.slotB }
    private var bonding: BondingType? { model.state.bondingType }

    // Cation/anion ordering — prefer derivedCharge, else Metal/Metalloid is the cation.
    private func ionicPair(_ a: ZoneState, _ b: ZoneState) -> (cation: ZoneState, anion: ZoneState) {
        if let ca = a.derivedCharge, let cb = b.derivedCharge, ca != 0 || cb != 0 {
            return ca > 0 ? (a, b) : (b, a)
        }
        let aCation = a.elementClass == .metal || a.elementClass == .metalloid
        return aCation ? (a, b) : (b, a)
    }

    private var applyEnabled: Bool {
        guard bonding == .ionic else { return true }
        return slotA?.status != .deducing && slotB?.status != .deducing
    }

    var body: some View {
        if model.state.canvasPhase == .explaining, let a = slotA, let b = slotB, let bonding {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(label(bonding))
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)

                    if bonding == .ionic {
                        VStack(spacing: 8) {
                            slotPanel(a, slot: .a)
                            slotPanel(b, slot: .b)
                        }
                    }

                    Divider().overlay(Theme.muted.opacity(0.2))
                    summary(bonding, a, b).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        model.send(.dismissExplanation)
                    } label: {
                        Text("Apply →").font(.system(size: 14, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .foregroundStyle(applyEnabled ? Theme.accent : .white.opacity(0.3))
                    .background((applyEnabled ? Theme.accent.opacity(0.3) : .white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(applyEnabled ? Theme.accent : .white.opacity(0.1), lineWidth: 1))
                    .disabled(!applyEnabled)
                }
                .padding(20)
                .frame(maxWidth: 420)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.muted.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 12)
            }
        }
    }

    private func label(_ b: BondingType) -> String {
        switch b { case .ionic: "Ionic Bonding"; case .covalent: "Covalent Bonding"; case .metallic: "Metallic Bonding" }
    }

    @ViewBuilder private func slotPanel(_ zone: ZoneState, slot: ChemCore.Slot) -> some View {
        Group {
            if zone.status == .deducing {
                TransitionMetalPickerView(zone: zone) { charge in model.send(.pickTMCharge(slot: slot, charge: charge)) }
            } else if zone.status == .neutral {
                Text("\(zone.symbol) — charge to be determined").font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            } else {
                Text(chargeExplanation(zone)).font(.system(size: 13)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func summary(_ bonding: BondingType, _ a: ZoneState, _ b: ZoneState) -> some View {
        switch bonding {
        case .ionic:
            let pair = ionicPair(a, b)
            if pair.cation.status == .ionized, pair.anion.status == .ionized,
               let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                let formulaStr = ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                              anionSymbol: pair.anion.symbol, anionCharge: ac,
                                              anionIsPolyatomic: pair.anion.isPolyatomic)
                let prefix: Text = Text("Crossover method: each charge becomes the other ion's subscript → ")
                let bold: Text = Text(formulaStr).fontWeight(.bold).foregroundColor(.white)
                let result: Text = prefix + bold
                result
            } else {
                EmptyView()
            }
        case .covalent:
            let aN = electronsNeeded(a.valenceElectrons), bN = electronsNeeded(b.valenceElectrons)
            Text("\(a.symbol) needs \(aN) more electron\(aN != 1 ? "s" : "") and \(b.symbol) needs \(bN) electron\(bN != 1 ? "s" : "") — they share electrons to complete their octets.")
        case .metallic:
            if a.symbol == b.symbol {
                Text("Each \(a.symbol) atom contributes \(a.valenceElectrons) valence electron\(a.valenceElectrons != 1 ? "s" : "") to a delocalised electron sea. The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons.")
            } else {
                Text("Each \(a.symbol) atom contributes \(a.valenceElectrons) electron\(a.valenceElectrons != 1 ? "s" : "") and each \(b.symbol) atom contributes \(b.valenceElectrons) electron\(b.valenceElectrons != 1 ? "s" : ""). The positive metal ions are held in a lattice by electrostatic attraction to the sea of electrons.")
            }
        }
    }
}
