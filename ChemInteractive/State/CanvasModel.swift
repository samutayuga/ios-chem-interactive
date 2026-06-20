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

    init() {
        // Bundled resource; a load failure is a developer error, not a user path.
        let pt = try! PeriodicTable.load()
        self.elements = pt.elements
    }

    func send(_ action: CanvasAction) {
        state = canvasReducer(state, action)
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
        selectedToken = (selectedToken == token) ? nil : token
    }

    func clearSelection() {
        selectedToken = nil
    }
}

#if DEBUG
extension CanvasModel {
    enum DiagramPreview: String {
        case crossover, ionic, covalent, metallic
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
            drop("Na", .a); drop("Cl", .b); send(.dismissExplanation); send(.crossoverComplete)  // .complete
        case .covalent:
            drop("O", .a); drop("O", .b); send(.dismissExplanation)              // .showingCovalent
        case .metallic:
            drop("Na", .a); drop("Mg", .b); send(.dismissExplanation)            // .showingMetallic
        }
    }

    /// Parses `-diagramPreview <name>` from launch arguments.
    static func debugPreviewArgument(_ args: [String]) -> DiagramPreview? {
        guard let i = args.firstIndex(of: "-diagramPreview"), i + 1 < args.count else { return nil }
        return DiagramPreview(rawValue: args[i + 1])
    }
}
#endif
