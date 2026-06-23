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
