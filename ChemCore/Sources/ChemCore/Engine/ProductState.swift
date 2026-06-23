/// The standard-state physical form of a result compound, for the result badge.
public enum ProductState: String, Sendable {
    case solid = "Solid", liquid = "Liquid", gas = "Gas"
}

/// Heuristic standard-state (~25 °C, 1 atm) of the product compound. Deliberately
/// approximate, for teaching:
/// - **Ionic** and **metallic** products are extended lattices → solid.
/// - **Covalent** products are discrete molecules, so the state is estimated from the
///   constituent elements' own standard states: any gaseous constituent → gas (CO₂, SO₂,
///   O₂), else any liquid constituent → liquid, else solid. Water is special-cased to
///   liquid since the light-element gas guess would otherwise miss it.
public func predictProductState(bonding: BondingType, a: ZoneState, b: ZoneState) -> ProductState {
    switch bonding {
    case .ionic, .metallic:
        return .solid
    case .covalent:
        if Set([a.symbol, b.symbol]) == ["H", "O"] { return .liquid }   // H₂O
        let states = [a.stateOfMatter, b.stateOfMatter]
        if states.contains(.gas) { return .gas }
        if states.contains(.liquid) { return .liquid }
        return .solid
    }
}
