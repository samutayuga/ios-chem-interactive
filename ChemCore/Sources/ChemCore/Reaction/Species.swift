import Foundation

/// One placed species: a neutral element or a (poly)atomic ion.
public struct Species: Equatable, Sendable {
    public let symbol: String
    public let atomicMass: Double
    public let charge: Int?
    public let elementClass: ElementClass
    public let isPolyatomic: Bool
    public let valenceElectrons: Int
    public let group: Int
    public let period: Int
    public let composition: [String: Int]

    public init(symbol: String, atomicMass: Double, charge: Int?,
                elementClass: ElementClass, isPolyatomic: Bool,
                valenceElectrons: Int, group: Int, period: Int,
                composition: [String: Int]) {
        self.symbol = symbol; self.atomicMass = atomicMass; self.charge = charge
        self.elementClass = elementClass; self.isPolyatomic = isPolyatomic
        self.valenceElectrons = valenceElectrons; self.group = group
        self.period = period; self.composition = composition
    }
}
