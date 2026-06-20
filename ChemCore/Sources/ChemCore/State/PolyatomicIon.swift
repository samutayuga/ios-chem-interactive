public struct PolyatomicIon: Equatable, Sendable {
    public let symbol: String
    public let name: String
    public let charge: Int
    public let formula: String

    public init(symbol: String, name: String, charge: Int, formula: String) {
        self.symbol = symbol; self.name = name; self.charge = charge; self.formula = formula
    }

    public static let polyatomicIons: [PolyatomicIon] = [
        PolyatomicIon(symbol: "OH",  name: "Hydroxide", charge: -1, formula: "OH⁻"),
        PolyatomicIon(symbol: "NO₃", name: "Nitrate",   charge: -1, formula: "NO₃⁻"),
        PolyatomicIon(symbol: "SO₄", name: "Sulfate",   charge: -2, formula: "SO₄²⁻"),
        PolyatomicIon(symbol: "CO₃", name: "Carbonate", charge: -2, formula: "CO₃²⁻"),
        PolyatomicIon(symbol: "PO₄", name: "Phosphate", charge: -3, formula: "PO₄³⁻"),
        PolyatomicIon(symbol: "NH₄", name: "Ammonium",  charge: 1,  formula: "NH₄⁺"),
    ]
}
