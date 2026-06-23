import SwiftUI
import ChemCore

struct BridgeView: View {
    @Environment(CanvasModel.self) private var model

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
                if let a = state.slotA, let b = state.slotB, let result = model.stoichResult {
                    VStack(spacing: 12) {
                        Text("Tap a flask to set its amount; tap a reactant in the equation for detail")
                            .font(.caption2).foregroundStyle(Theme.text.opacity(0.7))
                            .multilineTextAlignment(.center)
                        StoichResultPanel(result: result, symbolA: a.symbol, symbolB: b.symbol,
                                          productFormula: model.productFormula)
                        ResetButton { model.send(.reset) }
                    }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Helpers

    private var stoichiometryButton: some View {
        Button("Stoichiometry") { model.send(.startStoichiometry) }
            .buttonStyle(.borderedProminent)
    }
}
