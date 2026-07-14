import Foundation
import ChemCore

/// Pure conversion from placed ZoneStates to ChemCore reaction inputs. Charge
/// assignment is pair-aware so acids (HCl) read ionic while covalent fuels (CH₄) do not.
enum SpeciesMapping {
    static func composition(for z: ZoneState, ions: [PolyatomicIon]) -> [String: Int] {
        if z.isPolyatomic {
            return ions.first { $0.symbol == z.symbol }?.composition ?? [:]
        }
        return [z.symbol: 1]
    }

    static func atomicMass(for z: ZoneState, elements: [Element], ions: [PolyatomicIon]) -> Double? {
        if z.isPolyatomic {
            guard let ion = ions.first(where: { $0.symbol == z.symbol }) else { return nil }
            var total = 0.0
            for (sym, n) in ion.composition {
                guard let m = elements.first(where: { $0.symbol == sym })?.atomicMass else { return nil }
                total += m * Double(n)
            }
            return total
        }
        return elements.first { $0.symbol == z.symbol }?.atomicMass
    }

    static func toSpecies(_ z: ZoneState, charge: Int?, elements: [Element], ions: [PolyatomicIon]) -> Species? {
        guard let m = atomicMass(for: z, elements: elements, ions: ions) else { return nil }
        return Species(symbol: z.symbol, atomicMass: m, charge: charge,
                       elementClass: z.elementClass, isPolyatomic: z.isPolyatomic,
                       valenceElectrons: z.valenceElectrons, group: z.group, period: z.period,
                       composition: composition(for: z, ions: ions))
    }

    /// The charge a species carries when its zone is ionic (or a bare element whose
    /// charge a later product crossover needs).
    static func ionicCharge(_ z: ZoneState) -> Int? {
        if z.isPolyatomic { return z.oxidationStates.first }        // ZoneState(polyatomic:) stores [charge]
        if z.isTransition { return z.derivedCharge }
        if z.symbol == "H" { return 1 }
        if z.elementClass == .metal { return z.derivedCharge ?? z.oxidationStates.first { $0 > 0 } }
        return z.oxidationStates.first { $0 < 0 }                   // nonmetal anion
    }

    static func isAcidPair(_ a: ZoneState, _ b: ZoneState) -> Bool {
        (a.symbol == "H" && b.group == 17) || (b.symbol == "H" && a.group == 17)
    }

    static func isIonicPair(_ a: ZoneState, _ b: ZoneState) -> Bool {
        if a.isPolyatomic || b.isPolyatomic { return true }
        let metals = [a, b].filter { $0.elementClass == .metal }.count
        if metals == 1 { return true }
        if metals == 2 { return false }
        return isAcidPair(a, b)
    }

    static func buildReactant(_ zones: [ZoneState], elements: [Element], ions: [PolyatomicIon]) -> Reactant? {
        guard !zones.isEmpty, zones.count <= 2 else { return nil }
        for z in zones where z.isTransition && z.derivedCharge == nil { return nil }

        let charges: [Int?]
        if zones.count == 1 {
            charges = [ionicCharge(zones[0])]
        } else if isIonicPair(zones[0], zones[1]) {
            charges = [ionicCharge(zones[0]), ionicCharge(zones[1])]
        } else {
            charges = [nil, nil]   // covalent path
        }

        let specs = zip(zones, charges).compactMap {
            toSpecies($0.0, charge: $0.1, elements: elements, ions: ions)
        }
        guard specs.count == zones.count else { return nil }
        return makeReactant(specs)
    }
}
