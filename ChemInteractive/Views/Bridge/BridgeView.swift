import SwiftUI
import ChemCore

struct BridgeView: View {
    @Environment(CanvasModel.self) private var model

    @State private var entryA: ReactantEntry?
    @State private var entryB: ReactantEntry?
    @State private var showPopoverA = false
    @State private var showPopoverB = false

    private var state: CanvasState { model.state }

    var body: some View {
        VStack(spacing: 16) {
            Text("⇌").font(.system(size: 28)).foregroundStyle(Theme.accent.opacity(0.6))

            switch state.canvasPhase {
            case .animatingCrossover:
                if let a = state.slotA, let b = state.slotB {
                    let pair = ionicPair(a, b)
                    CrossoverAnimatorView(cation: pair.cation, anion: pair.anion) {
                        model.send(.crossoverComplete)
                    }
                } else {
                    // Defensive: the reducer always fills both slots before this phase,
                    // but never leave the machine wedged with no path to .complete.
                    ProgressView().tint(Theme.accent)
                        .onAppear { DispatchQueue.main.async { model.send(.crossoverComplete) } }
                }

            case .complete:
                if let a = state.slotA, let b = state.slotB {
                    let pair = ionicPair(a, b)
                    VStack(spacing: 12) {
                        if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                            Text(ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                              anionSymbol: pair.anion.symbol, anionCharge: ac,
                                              anionIsPolyatomic: pair.anion.isPolyatomic))
                                .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                            Text(ionicCompoundName(cation: pair.cation, anion: pair.anion,
                                                   elements: model.elements, ions: model.polyatomicIons))
                                .font(.system(size: 14)).foregroundStyle(Theme.text)
                                .multilineTextAlignment(.center)
                            ProductStateBadge(state: predictProductState(bonding: .ionic,
                                                                         a: pair.cation, b: pair.anion))
                        }
                        BondingDiagramView(cation: pair.cation, anion: pair.anion)
                        stoichiometryButton
                        ResetButton { model.send(.reset) }
                    }
                }

            case .showingCovalent:
                if let a = state.slotA, let b = state.slotB {
                    VStack(spacing: 12) {
                        CovalentLewisView(slotA: a, slotB: b)
                        stoichiometryButton
                        ResetButton { model.send(.reset) }
                    }
                }

            case .showingMetallic:
                if let a = state.slotA, let b = state.slotB {
                    VStack(spacing: 12) {
                        MetallicSeaView(slotA: a, slotB: b)
                        ResetButton { model.send(.reset) }
                    }
                }

            case .stoichiometry:
                if let a = state.slotA, let b = state.slotB,
                   let subs = productSubscripts(a, b),
                   let specA = reactantSpec(a, subscriptInProduct: subs.0, entry: entryA),
                   let specB = reactantSpec(b, subscriptInProduct: subs.1, entry: entryB) {
                    let result = solveStoichiometry(a: specA, b: specB)
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            reactantChip(a.symbol, show: $showPopoverA, entry: $entryA)
                            reactantChip(b.symbol, show: $showPopoverB, entry: $entryB)
                        }
                        StoichResultPanel(result: result, symbolA: a.symbol, symbolB: b.symbol,
                                          productFormula: productFormula(a, b))
                        ResetButton { model.send(.reset) }
                    }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: state.canvasPhase) { _, newPhase in
            if newPhase == .selecting || newPhase == .slotAFilled {
                entryA = nil; entryB = nil
                showPopoverA = false; showPopoverB = false
            }
        }
    }

    // MARK: - Helpers

    private func atomicMass(_ symbol: String) -> Double? {
        model.elements.first { $0.symbol == symbol }?.atomicMass
    }

    private func reactantSpec(_ zone: ZoneState, subscriptInProduct: Int,
                              entry: ReactantEntry?) -> ReactantSpec? {
        guard let m = atomicMass(zone.symbol) else { return nil }
        return ReactantSpec(symbol: zone.symbol, atomicMass: m,
                            subscriptInProduct: subscriptInProduct,
                            isDiatomic: naturallyDiatomic.contains(zone.symbol),
                            entry: entry)
    }

    /// (subscript of slotA, subscript of slotB) in the product. Ionic uses the
    /// crossover subscripts mapped back to slot order; covalent uses covalentStoich.
    private func productSubscripts(_ a: ZoneState, _ b: ZoneState) -> (Int, Int)? {
        switch state.bondingType {
        case .ionic:
            let pair = ionicPair(a, b)
            let cm = crossoverModel(cation: pair.cation, anion: pair.anion)
            let aIsCation = pair.cation.symbol == a.symbol
            return aIsCation ? (cm.cationSub, cm.anionSub) : (cm.anionSub, cm.cationSub)
        case .covalent:
            let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                                   veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
            return (s.nA, s.nB)
        default:
            return nil
        }
    }

    /// Single-unit product formula (e.g. "NaCl", "H₂O"); the panel prepends the coefficient.
    private func productFormula(_ a: ZoneState, _ b: ZoneState) -> String {
        switch state.bondingType {
        case .ionic:
            let pair = ionicPair(a, b)
            if let cc = pair.cation.derivedCharge, let ac = pair.anion.derivedCharge {
                return ionicFormula(cationSymbol: pair.cation.symbol, cationCharge: cc,
                                    anionSymbol: pair.anion.symbol, anionCharge: ac,
                                    anionIsPolyatomic: pair.anion.isPolyatomic)
            }
            return ""
        case .covalent:
            let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                                   veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
            let homo = a.symbol == b.symbol
            let aFirst = iupacFirst(a.symbol, b.symbol)
            let fst = aFirst ? a.symbol : b.symbol
            let fstN = aFirst ? s.nA : s.nB
            let snd = aFirst ? b.symbol : a.symbol
            let sndN = aFirst ? s.nB : s.nA
            return homo
                ? "\(a.symbol)\((s.nA + s.nB) > 1 ? subscriptGlyphs(s.nA + s.nB) : "")"
                : "\(fst)\(fstN > 1 ? subscriptGlyphs(fstN) : "")\(snd)\(sndN > 1 ? subscriptGlyphs(sndN) : "")"
        default:
            return ""
        }
    }

    @ViewBuilder
    private func reactantChip(_ symbol: String, show: Binding<Bool>,
                              entry: Binding<ReactantEntry?>) -> some View {
        Button { show.wrappedValue = true } label: {
            VStack(spacing: 2) {
                Text(symbol).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                if let e = entry.wrappedValue {
                    Text("\(e.value, specifier: "%.3g") \(e.unit == .mole ? "mol" : "g")")
                        .font(.caption2).foregroundStyle(Theme.text)
                } else {
                    Text("tap to set").font(.caption2).foregroundStyle(Theme.text.opacity(0.6))
                }
            }
            .padding(10)
            .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
        }
        .popover(isPresented: show) {
            ReactantQuantityPopover(symbol: symbol, entry: entry)
        }
    }

    private var stoichiometryButton: some View {
        Button("Stoichiometry") { model.send(.startStoichiometry) }
            .buttonStyle(.borderedProminent)
    }
}
