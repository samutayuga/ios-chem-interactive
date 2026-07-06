import Foundation

private let group1: Set<String> = ["Li", "Na", "K", "Rb", "Cs", "Fr"]
private let group2: Set<String> = ["Be", "Mg", "Ca", "Sr", "Ba", "Ra"]
private let halogensMinusOne: Set<String> = ["Cl", "Br", "I"]

/// The fixed oxidation state for elements governed by a simple rule, else nil.
/// No peroxide/hydride exceptions — this engine never produces them.
private func fixedState(_ symbol: String) -> Int? {
    switch symbol {
    case "F": return -1
    case "O": return -2
    case "H": return 1
    default:
        if halogensMinusOne.contains(symbol) { return -1 }
        if group1.contains(symbol) { return 1 }
        if group2.contains(symbol) { return 2 }
        return nil
    }
}

private func atomCount(_ c: [String: Int]) -> Int { c.values.reduce(0, +) }

/// Largest k with comp ⊇ k·ion, or nil if the ion is not wholly contained.
private func maxMultiple(_ comp: [String: Int], _ ion: [String: Int]) -> Int? {
    var k = Int.max
    for (sym, n) in ion {
        let have = comp[sym] ?? 0
        if have < n { return nil }
        k = min(k, have / n)
    }
    return k == Int.max ? nil : k
}

/// Oxidation states inside a polyatomic ion: O/H fixed, the central atom solved so
/// the ion's atoms sum to its charge. nil if not resolvable to a single unknown.
private func statesWithinIon(_ ion: PolyatomicIon) -> [String: Int]? {
    var states: [String: Int] = [:]
    var assignedSum = 0
    var unknown: String?
    for (sym, n) in ion.composition {
        if let fx = fixedState(sym) { states[sym] = fx; assignedSum += fx * n }
        else if unknown == nil { unknown = sym }
        else { return nil }
    }
    if let u = unknown {
        let count = ion.composition[u]!
        let need = ion.charge - assignedSum
        guard need % count == 0 else { return nil }
        states[u] = need / count
    } else if assignedSum != ion.charge {
        return nil
    }
    return states
}

/// Try to read the compound as (counter-ion)·(known polyatomic ion): factor the ion
/// out, assign the disjoint remainder element the charge that balances it.
private func factorPolyatomic(_ comp: [String: Int]) -> [String: Int]? {
    let ions = PolyatomicIon.polyatomicIons.sorted { atomCount($0.composition) > atomCount($1.composition) }
    for ion in ions {
        guard let k = maxMultiple(comp, ion.composition), k >= 1 else { continue }
        var remainder = comp
        for (sym, n) in ion.composition {
            remainder[sym, default: 0] -= n * k
            if remainder[sym] == 0 { remainder[sym] = nil }
        }
        // Remainder must be a single element, disjoint from the ion's elements.
        guard remainder.count == 1, let (counterSym, counterCount) = remainder.first,
              Set(remainder.keys).isDisjoint(with: ion.composition.keys),
              let ionStates = statesWithinIon(ion) else { continue }
        let counterTotal = -ion.charge * k
        guard counterCount != 0, counterTotal % counterCount == 0 else { continue }
        var result = ionStates
        result[counterSym] = counterTotal / counterCount
        return result
    }
    return nil
}

/// Element rules + solve the single remaining unknown so a neutral compound sums to 0.
private func byElementRules(_ comp: [String: Int]) -> [String: Int]? {
    var states: [String: Int] = [:]
    var assignedSum = 0
    var unknowns: [String] = []
    for (sym, n) in comp {
        if let fx = fixedState(sym) { states[sym] = fx; assignedSum += fx * n }
        else { unknowns.append(sym) }
    }
    guard unknowns.count <= 1 else { return nil }
    if let u = unknowns.first {
        let count = comp[u]!
        let need = -assignedSum
        guard need % count == 0 else { return nil }
        states[u] = need / count
    } else if assignedSum != 0 {
        return nil
    }
    return states
}

/// Oxidation state of every element in a NEUTRAL compound, or nil if the standard
/// rules leave it under-determined.
/// Known limitation: a compound with the same element in two oxidation environments
/// (e.g. NH₄NO₃) collapses to one composition entry and yields a single averaged
/// value rather than nil — out of scope for this engine's reaction set.
public func oxidationState(of composition: [String: Int]) -> [String: Int]? {
    if composition.count == 1, let sym = composition.keys.first {
        return [sym: 0]                                  // free element
    }
    if let byIon = factorPolyatomic(composition) { return byIon }
    return byElementRules(composition)
}
