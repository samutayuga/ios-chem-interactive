// ChemCore/Sources/ChemCore/Reaction/ReactionSolver.swift
import Foundation

public struct BalancedTerm: Equatable, Sendable {
    public let coeff: Int
    public let formula: String
    public let molarMass: Double
    public let composition: [String: Int]
}

public struct ReactionResult: Equatable, Sendable {
    public let reactionClass: ReactionClass
    public let reactants: [BalancedTerm]
    public let products: [BalancedTerm]
    public let limiting: LimitingSide
    public let yields: [AmountResult]
    public let excess: AmountResult
    public let messages: [String]
    public let feasible: Bool
}

public enum ReactionError: Error, Equatable {
    case unbalanceable, noProducts, unknownReactionClass, missingAtomicMass(String)
}

private func molarMass(_ comp: [String: Int], _ atomicMass: (String) -> Double?) -> Double? {
    var total = 0.0
    for (sym, n) in comp {
        guard let m = atomicMass(sym) else { return nil }
        total += m * Double(n)
    }
    return total
}

public func solveReaction(_ r1: Reactant, _ r2: Reactant,
                          entry1: ReactantEntry?, entry2: ReactantEntry?,
                          atomicMass: (String) -> Double?) -> Result<ReactionResult, ReactionError> {
    let cls = classifyReaction(r1, r2)
    if cls == .none { return .failure(.unknownReactionClass) }

    // Product prediction — infeasible is a valid, non-error result.
    let prediction = predictProducts(cls, r1, r2)
    let productList: [Product]
    switch prediction {
    case .infeasible(let reason):
        let reactants = [r1, r2].map {
            BalancedTerm(coeff: 1, formula: $0.formula, molarMass: $0.molarMass, composition: $0.composition)
        }
        return .success(ReactionResult(reactionClass: cls, reactants: reactants, products: [],
                                       limiting: .both, yields: [], excess: AmountResult(moles: 0, mass: 0),
                                       messages: [reason], feasible: false))
    case .products(let list):
        if list.isEmpty { return .failure(.noProducts) }
        productList = list
    }

    // Balance.
    let reactantComps = [r1.composition, r2.composition]
    let productComps = productList.map(\.composition)
    guard let coeffs = balance(reactants: reactantComps, products: productComps) else {
        return .failure(.unbalanceable)
    }
    let coeffA = coeffs[0], coeffB = coeffs[1]
    let productCoeffs = Array(coeffs[2...])

    // Molar masses.
    guard let mmA = molarMass(r1.composition, atomicMass) else { return .failure(.missingAtomicMass(firstMissing(r1.composition, atomicMass))) }
    guard let mmB = molarMass(r2.composition, atomicMass) else { return .failure(.missingAtomicMass(firstMissing(r2.composition, atomicMass))) }
    var productTerms: [BalancedTerm] = []
    var productMasses: [Double] = []
    for (p, c) in zip(productList, productCoeffs) {
        guard let mm = molarMass(p.composition, atomicMass) else {
            return .failure(.missingAtomicMass(firstMissing(p.composition, atomicMass)))
        }
        productMasses.append(mm)
        productTerms.append(BalancedTerm(coeff: c, formula: p.formula, molarMass: mm, composition: p.composition))
    }

    // Extent ξ from limiting reactant.
    func moles(_ e: ReactantEntry?, _ mm: Double) -> Double? {
        guard let e else { return nil }
        return e.unit == .mole ? e.value : e.value / mm
    }
    let molA = moles(entry1, mmA), molB = moles(entry2, mmB)
    let extentA = molA.map { $0 / Double(coeffA) }
    let extentB = molB.map { $0 / Double(coeffB) }

    let xi: Double
    let limiting: LimitingSide
    switch (extentA, extentB) {
    case (nil, nil):        xi = 1;  limiting = .both
    case (let ea?, nil):    xi = ea; limiting = .a
    case (nil, let eb?):    xi = eb; limiting = .b
    case (let ea?, let eb?):
        if ea < eb {        xi = ea; limiting = .a }
        else if eb < ea {   xi = eb; limiting = .b }
        else {              xi = ea; limiting = .both }
    }

    let yields = zip(productCoeffs, productMasses).map { c, mm in
        AmountResult(moles: Double(c) * xi, mass: Double(c) * xi * mm)
    }

    var excess = AmountResult(moles: 0, mass: 0)
    if limiting == .a, let mb = molB {
        let left = max(0, mb - Double(coeffB) * xi)
        excess = AmountResult(moles: left, mass: left * mmB)
    } else if limiting == .b, let ma = molA {
        let left = max(0, ma - Double(coeffA) * xi)
        excess = AmountResult(moles: left, mass: left * mmA)
    }

    var messages: [String] = []
    if r1.formula.hasSuffix("₂") && naturallyDiatomic.contains(r1.species.first?.symbol ?? "") {
        messages.append("\(r1.species[0].symbol) only exists as \(r1.species[0].symbol)₂")
    }
    if r2.formula.hasSuffix("₂") && naturallyDiatomic.contains(r2.species.first?.symbol ?? "") {
        messages.append("\(r2.species[0].symbol) only exists as \(r2.species[0].symbol)₂")
    }

    let reactants = [
        BalancedTerm(coeff: coeffA, formula: r1.formula, molarMass: mmA, composition: r1.composition),
        BalancedTerm(coeff: coeffB, formula: r2.formula, molarMass: mmB, composition: r2.composition),
    ]
    return .success(ReactionResult(reactionClass: cls, reactants: reactants, products: productTerms,
                                   limiting: limiting, yields: yields, excess: excess,
                                   messages: messages, feasible: true))
}

private func firstMissing(_ comp: [String: Int], _ atomicMass: (String) -> Double?) -> String {
    comp.keys.first { atomicMass($0) == nil } ?? "?"
}
