import Foundation

/// A reactant compound built from 1 or 2 species using the existing bonding rules.
public struct Reactant: Equatable, Sendable {
    public let species: [Species]
    public let formula: String
    public let composition: [String: Int]
    public let molarMass: Double
    public let cation: Species?
    public let anion: Species?
    public let isBareElement: Bool
}

private func scaled(_ comp: [String: Int], by n: Int) -> [String: Int] {
    comp.mapValues { $0 * n }
}
private func merge(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
    a.merging(b) { $0 + $1 }
}

public func makeReactant(_ species: [Species]) -> Reactant {
    if species.count == 1 {
        let s = species[0]
        let diatomic = naturallyDiatomic.contains(s.symbol) && !s.isPolyatomic
        let count = diatomic ? 2 : 1
        let comp = scaled(s.composition, by: count)
        let formula = "\(s.symbol)\(formulaSubscript(count))"
        return Reactant(species: species, formula: formula, composition: comp,
                        molarMass: s.atomicMass * Double(count),
                        cation: nil, anion: nil, isBareElement: !s.isPolyatomic)
    }

    let a = species[0], b = species[1]
    // Check for explicit opposite charges (e.g., H+ and Cl-)
    // An acid like HCl is covalent by electronegativity (both non-metals),
    // but is modeled as ionic (H+ cation + anion) for reaction purposes.
    // This relies on callers setting `charge` only to express ionic intent;
    // neutral elements must carry `charge == nil` for the covalent path to apply.
    let hasOppositeCharges = a.charge != nil && b.charge != nil
        && (a.charge ?? 0) * (b.charge ?? 0) < 0
    let ionic = a.isPolyatomic || b.isPolyatomic
        || hasOppositeCharges
        || determineBonding(a.elementClass, b.elementClass) == .ionic

    if ionic {
        // Cation = positive charge (or the metal); anion = the other.
        let (cation, anion): (Species, Species) =
            (a.charge ?? cationBias(a)) >= (b.charge ?? cationBias(b)) ? (a, b) : (b, a)
        let sub = crossoverSubscripts(cationCharge: cation.charge ?? 1,
                                      anionCharge: anion.charge ?? -1)
        let comp = merge(scaled(cation.composition, by: sub.cationSub),
                         scaled(anion.composition, by: sub.anionSub))
        let formula = binaryFormula(first: cation.symbol, firstCount: sub.cationSub,
                                    second: anion.symbol, secondCount: sub.anionSub,
                                    secondIsPolyatomic: anion.isPolyatomic)
        let mass = cation.atomicMass * Double(sub.cationSub)
                 + anion.atomicMass * Double(sub.anionSub)
        return Reactant(species: species, formula: formula, composition: comp,
                        molarMass: mass, cation: cation, anion: anion, isBareElement: false)
    }

    // Covalent.
    let s = covalentStoich(veA: a.valenceElectrons, groupA: a.group, periodA: a.period,
                           veB: b.valenceElectrons, groupB: b.group, periodB: b.period)
    let aFirst = iupacFirst(a.symbol, b.symbol)
    let first = aFirst ? a : b
    let firstN = aFirst ? s.nA : s.nB
    let second = aFirst ? b : a
    let secondN = aFirst ? s.nB : s.nA
    let comp = merge(scaled(a.composition, by: s.nA), scaled(b.composition, by: s.nB))
    let formula = binaryFormula(first: first.symbol, firstCount: firstN,
                                second: second.symbol, secondCount: secondN,
                                secondIsPolyatomic: false)
    let mass = a.atomicMass * Double(s.nA) + b.atomicMass * Double(s.nB)
    return Reactant(species: species, formula: formula, composition: comp,
                    molarMass: mass, cation: nil, anion: nil, isBareElement: false)
}

/// Metals bias toward cation, non-metals toward anion, when charge is absent.
private func cationBias(_ s: Species) -> Int {
    s.elementClass == .metal ? 1 : -1
}
