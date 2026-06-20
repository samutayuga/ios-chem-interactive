public enum StateOfMatter: String, Equatable {
    case solid = "Solid", liquid = "Liquid", gas = "Gas"
}

public struct Isotope: Equatable {
    public let massNumber: Int
    public let relativeMass: Double
    public let abundance: Double
    public init(massNumber: Int, relativeMass: Double, abundance: Double) {
        self.massNumber = massNumber; self.relativeMass = relativeMass; self.abundance = abundance
    }
}

/// Abundance-weighted mean of isotope relative masses, or nil if empty / zero abundance.
public func atomicMassFromIsotopes(_ isotopes: [Isotope]) -> Double? {
    if isotopes.isEmpty { return nil }
    let total = isotopes.reduce(0.0) { $0 + $1.abundance }
    if total == 0.0 { return nil }
    let weighted = isotopes.reduce(0.0) { $0 + $1.relativeMass * $1.abundance }
    return weighted / total
}

public func isotopeMassMatches(storedMass: Double, isotopes: [Isotope], tolerance: Double) -> Bool {
    guard let mass = atomicMassFromIsotopes(isotopes) else { return false }
    return abs(mass - storedMass) <= tolerance
}

/// Physical state at `temperatureK`, or nil when either point is unknown.
public func stateAt(meltingPoint: Double?, boilingPoint: Double?, temperatureK: Double) -> StateOfMatter? {
    guard let mp = meltingPoint, let bp = boilingPoint else { return nil }
    if temperatureK < mp { return .solid }
    if temperatureK < bp { return .liquid }
    return .gas
}
