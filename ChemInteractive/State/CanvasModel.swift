import Foundation
import Observation
import CoreTransferable
import ChemCore

/// The drag/tap payload. Carries only what is needed to rebuild a `ZoneState`
/// from the model — `ZoneState` construction stays in ChemCore.
struct TokenTransfer: Codable, Transferable, Equatable {
    let symbol: String
    let isPolyatomic: Bool

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

@Observable
final class CanvasModel {
    private(set) var state: CanvasState = .initial
    let elements: [Element]
    let polyatomicIons: [PolyatomicIon] = PolyatomicIon.polyatomicIons
    private(set) var selectedToken: TokenTransfer?

    /// Transient stoichiometry quantities per slot (UI-only; never part of the
    /// reduced `CanvasState`). Set on the drop zones during the stoichiometry phase.
    var quantityA: ReactantEntry?
    var quantityB: ReactantEntry?

    func quantity(for slot: Slot) -> ReactantEntry? { slot == .a ? quantityA : quantityB }
    func setQuantity(_ entry: ReactantEntry?, for slot: Slot) {
        if slot == .a { quantityA = entry } else { quantityB = entry }
    }

    init() {
        // Bundled resource; a load failure is a developer error, not a user path.
        let pt = try! PeriodicTable.load()
        self.elements = pt.elements
    }

    func send(_ action: CanvasAction) {
        state = canvasReducer(state, action)
        // Reset stoichiometry inputs once a new reaction starts, so quantities
        // never leak from a previous product into the next one.
        if state.canvasPhase == .selecting || state.canvasPhase == .slotAFilled {
            quantityA = nil
            quantityB = nil
        }
    }

    /// Rebuilds the ChemCore `ZoneState` for a dragged/tapped token, or nil if unknown.
    func zoneState(for token: TokenTransfer) -> ZoneState? {
        if token.isPolyatomic {
            guard let ion = polyatomicIons.first(where: { $0.symbol == token.symbol }) else { return nil }
            return ZoneState(polyatomic: ion)
        }
        guard let element = elements.first(where: { $0.symbol == token.symbol }) else { return nil }
        return ZoneState(element: element)
    }

    /// Resolves a token to a zone and dispatches a drop into `slot`; clears any pending selection.
    func place(_ token: TokenTransfer, in slot: Slot) {
        guard let zone = zoneState(for: token) else { return }
        send(.dropElement(slot: slot, zone: zone))
        clearSelection()
    }

    func select(_ token: TokenTransfer) {
        // Picking an element from the stoichiometry view returns to the bonding
        // feature: reset to the initial state, then carry the new selection.
        if state.canvasPhase == .stoichiometry {
            send(.reset)
        }
        selectedToken = (selectedToken == token) ? nil : token
    }

    func clearSelection() {
        selectedToken = nil
    }
}

#if DEBUG
extension CanvasModel {
    enum DiagramPreview: String {
        case crossover, ionic, mgcl2, na2o, explainIonic, covalent, co2, metallic, stoich
    }

    /// Replays real reducer actions to land in a terminal diagram state (for screenshots).
    func debugSeed(_ which: DiagramPreview) {
        func drop(_ symbol: String, _ slot: Slot, _ poly: Bool = false) {
            place(TokenTransfer(symbol: symbol, isPolyatomic: poly), in: slot)
        }
        switch which {
        case .crossover:
            drop("Na", .a); drop("Cl", .b); send(.dismissExplanation)            // .animatingCrossover (auto-advances)
        case .ionic:
            drop("Na", .a); drop("Cl", .b); send(.dismissExplanation); send(.crossoverComplete)  // .complete (NaCl 1:1)
        case .mgcl2:
            drop("Mg", .a); drop("Cl", .b); send(.dismissExplanation); send(.crossoverComplete)  // .complete (MgCl₂, anion coeff 2)
        case .na2o:
            drop("Na", .a); drop("O", .b); send(.dismissExplanation); send(.crossoverComplete)    // .complete (Na₂O, cation coeff 2)
        case .explainIonic:
            drop("Mg", .a); drop("Cl", .b)                                                          // .explaining (ionic explanation modal)
        case .covalent:
            drop("O", .a); drop("O", .b); send(.dismissExplanation)              // .showingCovalent (O₂)
        case .co2:
            drop("C", .a); drop("O", .b); send(.dismissExplanation)              // .showingCovalent (CO₂, 2 peripheral O)
        case .metallic:
            drop("Na", .a); drop("Mg", .b); send(.dismissExplanation)            // .showingMetallic
        case .stoich:
            drop("H", .a); drop("O", .b); send(.dismissExplanation)              // covalent H₂O
            send(.startStoichiometry)                                            // .stoichiometry
            quantityA = ReactantEntry(value: 2, unit: .mole)                     // 2 mol H₂
            quantityB = ReactantEntry(value: 1, unit: .mole)                     // 1 mol O₂
        }
    }

    /// Parses `-diagramPreview <name>` from launch arguments.
    static func debugPreviewArgument(_ args: [String]) -> DiagramPreview? {
        guard let i = args.firstIndex(of: "-diagramPreview"), i + 1 < args.count else { return nil }
        return DiagramPreview(rawValue: args[i + 1])
    }
}
#endif
