import Foundation
import Observation
import ChemCore

@Observable
final class ReactionLabModel {
    let elements: [Element]
    let polyatomicIons: [PolyatomicIon] = PolyatomicIon.polyatomicIons

    private(set) var zone1: [ZoneState] = []
    private(set) var zone2: [ZoneState] = []
    var quantity1: ReactantEntry?
    var quantity2: ReactantEntry?
    private(set) var pendingCharge: PendingCharge?

    struct PendingCharge: Equatable { let zone: Int; let index: Int }

    init() {
        let pt = try! PeriodicTable.load()
        self.elements = pt.elements
    }

    private func tokens(_ zone: Int) -> [ZoneState] { zone == 1 ? zone1 : zone2 }
    private func setTokens(_ v: [ZoneState], _ zone: Int) { if zone == 1 { zone1 = v } else { zone2 = v } }

    func zoneState(for token: TokenTransfer) -> ZoneState? {
        if token.isPolyatomic {
            guard let ion = polyatomicIons.first(where: { $0.symbol == token.symbol }) else { return nil }
            return ZoneState(polyatomic: ion)
        }
        guard let el = elements.first(where: { $0.symbol == token.symbol }) else { return nil }
        return ZoneState(element: el)
    }

    func place(_ token: TokenTransfer, inZone zone: Int) {
        guard pendingCharge == nil, let z = zoneState(for: token) else { return }
        var arr = tokens(zone)
        guard arr.count < 2 else { return }
        arr.append(z)
        setTokens(arr, zone)
        if z.isTransition && z.derivedCharge == nil {
            pendingCharge = PendingCharge(zone: zone, index: arr.count - 1)
        }
    }

    func pickCharge(_ charge: Int) {
        guard let p = pendingCharge else { return }
        var arr = tokens(p.zone)
        if p.index < arr.count {
            arr[p.index].derivedCharge = charge
            arr[p.index].status = .ionized
            setTokens(arr, p.zone)
        }
        pendingCharge = nil
    }

    func removeToken(zone: Int, index: Int) {
        var arr = tokens(zone)
        guard index < arr.count else { return }
        arr.remove(at: index)
        setTokens(arr, zone)
        recomputePendingCharge()
    }

    /// Re-derives the pending-charge slot from current zone contents: the first
    /// transition metal still lacking a picked charge, or nil if none remain.
    private func recomputePendingCharge() {
        for (zoneNum, arr) in [(1, zone1), (2, zone2)] {
            if let idx = arr.firstIndex(where: { $0.isTransition && $0.derivedCharge == nil }) {
                pendingCharge = PendingCharge(zone: zoneNum, index: idx)
                return
            }
        }
        pendingCharge = nil
    }

    func setQuantity(_ entry: ReactantEntry?, zone: Int) {
        if zone == 1 { quantity1 = entry } else { quantity2 = entry }
    }

    func reset() {
        zone1 = []; zone2 = []; quantity1 = nil; quantity2 = nil; pendingCharge = nil
    }

    var reactant1: Reactant? { buildReactant(zone1) }
    var reactant2: Reactant? { buildReactant(zone2) }

    private func buildReactant(_ zones: [ZoneState]) -> Reactant? {
        guard pendingCharge == nil else { return nil }
        return SpeciesMapping.buildReactant(zones, elements: elements, ions: polyatomicIons)
    }

    var result: Result<ReactionResult, ReactionError>? {
        guard pendingCharge == nil, let r1 = reactant1, let r2 = reactant2 else { return nil }
        return solveReaction(r1, r2, entry1: quantity1, entry2: quantity2) { [elements] sym in
            elements.first { $0.symbol == sym }?.atomicMass
        }
    }
}
