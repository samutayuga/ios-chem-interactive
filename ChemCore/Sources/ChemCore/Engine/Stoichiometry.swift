// ChemCore/Sources/ChemCore/Engine/Stoichiometry.swift
import Foundation

public enum QuantityUnit: String, Sendable, Equatable { case mole, mass }

public struct ReactantEntry: Equatable, Sendable {
    public let value: Double
    public let unit: QuantityUnit
    public init(value: Double, unit: QuantityUnit) {
        self.value = value; self.unit = unit
    }
}

public struct ReactantSpec: Equatable, Sendable {
    public let symbol: String
    public let atomicMass: Double
    public let subscriptInProduct: Int
    public let isDiatomic: Bool
    public let entry: ReactantEntry?
    public init(symbol: String, atomicMass: Double, subscriptInProduct: Int,
                isDiatomic: Bool, entry: ReactantEntry?) {
        self.symbol = symbol; self.atomicMass = atomicMass
        self.subscriptInProduct = subscriptInProduct
        self.isDiatomic = isDiatomic; self.entry = entry
    }
}

public struct BalancedEquation: Equatable, Sendable {
    public let coeffA: Int
    public let coeffB: Int
    public let coeffProduct: Int
    public let molecularityA: Int
    public let molecularityB: Int
}

public enum LimitingSide: Equatable, Sendable { case a, b, both }

public struct AmountResult: Equatable, Sendable {
    public let moles: Double
    public let mass: Double
}

public struct StoichResult: Equatable, Sendable {
    public let equation: BalancedEquation
    public let productMolarMass: Double
    public let limiting: LimitingSide
    public let yield: AmountResult
    public let excess: AmountResult
    public let diatomicMessages: [String]
}

public let naturallyDiatomic: Set<String> = ["H", "N", "O", "F", "Cl", "Br", "I"]

private func lcm(_ a: Int, _ b: Int) -> Int { a / gcd(a, b) * b }

public func molecularity(isDiatomic: Bool) -> Int { isDiatomic ? 2 : 1 }

/// Balance `coeffA·A_p + coeffB·B_q -> coeffProduct·AₓBᵧ` for smallest integers,
/// where x/y are the product subscripts and p/q the reactant molecularities.
public func balanceEquation(subscriptA x: Int, molecularityA p: Int,
                            subscriptB y: Int, molecularityB q: Int) -> BalancedEquation {
    let c0 = lcm(p / gcd(p, x), q / gcd(q, y))
    var a = c0 * x / p
    var b = c0 * y / q
    var c = c0
    let g = gcd(gcd(a, b), c)
    a /= g; b /= g; c /= g
    return BalancedEquation(coeffA: a, coeffB: b, coeffProduct: c,
                            molecularityA: p, molecularityB: q)
}

public func solveStoichiometry(a: ReactantSpec, b: ReactantSpec) -> StoichResult {
    let p = molecularity(isDiatomic: a.isDiatomic)
    let q = molecularity(isDiatomic: b.isDiatomic)
    let eqn = balanceEquation(subscriptA: a.subscriptInProduct, molecularityA: p,
                              subscriptB: b.subscriptInProduct, molecularityB: q)

    let unitMassA = Double(p) * a.atomicMass    // molar mass of A_p (X₂ when diatomic)
    let unitMassB = Double(q) * b.atomicMass
    let productMolarMass = Double(a.subscriptInProduct) * a.atomicMass
                         + Double(b.subscriptInProduct) * b.atomicMass

    func molesUnit(_ e: ReactantEntry?, _ unitMass: Double) -> Double? {
        guard let e else { return nil }
        switch e.unit {
        case .mole: return e.value
        case .mass: return e.value / unitMass
        }
    }
    let molA = molesUnit(a.entry, unitMassA)
    let molB = molesUnit(b.entry, unitMassB)
    let extentA = molA.map { $0 / Double(eqn.coeffA) }
    let extentB = molB.map { $0 / Double(eqn.coeffB) }

    let xi: Double
    let limiting: LimitingSide
    switch (extentA, extentB) {
    case (nil, nil):              xi = 1;  limiting = .both
    case (let ea?, nil):          xi = ea; limiting = .a
    case (nil, let eb?):          xi = eb; limiting = .b
    case (let ea?, let eb?):
        if ea < eb {              xi = ea; limiting = .a }
        else if eb < ea {         xi = eb; limiting = .b }
        else {                    xi = ea; limiting = .both }
    }

    let yieldMoles = Double(eqn.coeffProduct) * xi
    let yield = AmountResult(moles: yieldMoles, mass: yieldMoles * productMolarMass)

    var excess = AmountResult(moles: 0, mass: 0)
    if limiting == .a, let mb = molB {
        let left = mb - Double(eqn.coeffB) * xi
        excess = AmountResult(moles: left, mass: left * unitMassB)
    } else if limiting == .b, let ma = molA {
        let left = ma - Double(eqn.coeffA) * xi
        excess = AmountResult(moles: left, mass: left * unitMassA)
    }

    var messages: [String] = []
    if a.isDiatomic { messages.append("\(a.symbol) cannot exist as monoatomic, It only exist in \(a.symbol)₂") }
    if b.isDiatomic { messages.append("\(b.symbol) cannot exist as monoatomic, It only exist in \(b.symbol)₂") }

    return StoichResult(equation: eqn, productMolarMass: productMolarMass,
                        limiting: limiting, yield: yield, excess: excess,
                        diatomicMessages: messages)
}
