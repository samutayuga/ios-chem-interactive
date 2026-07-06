public struct PolyatomicIon: Equatable, Sendable {
    public let symbol: String
    public let name: String
    public let charge: Int
    public let formula: String
    public let composition: [String: Int]

    public init(symbol: String, name: String, charge: Int, formula: String, composition: [String: Int]) {
        self.symbol = symbol; self.name = name; self.charge = charge
        self.formula = formula; self.composition = composition
    }

    public static let polyatomicIons: [PolyatomicIon] = [
        PolyatomicIon(symbol: "OH",  name: "Hydroxide", charge: -1, formula: "OH⁻",  composition: ["O": 1, "H": 1]),
        PolyatomicIon(symbol: "NO₃", name: "Nitrate",   charge: -1, formula: "NO₃⁻", composition: ["N": 1, "O": 3]),
        PolyatomicIon(symbol: "SO₄", name: "Sulfate",   charge: -2, formula: "SO₄²⁻", composition: ["S": 1, "O": 4]),
        PolyatomicIon(symbol: "CO₃", name: "Carbonate", charge: -2, formula: "CO₃²⁻", composition: ["C": 1, "O": 3]),
        PolyatomicIon(symbol: "PO₄", name: "Phosphate", charge: -3, formula: "PO₄³⁻", composition: ["P": 1, "O": 4]),
        PolyatomicIon(symbol: "NH₄", name: "Ammonium",  charge: 1,  formula: "NH₄⁺",  composition: ["N": 1, "H": 4]),
    ]
}
