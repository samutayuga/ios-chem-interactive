import Foundation

public struct Element {
    public let raw: RawElement
    public let block: Block
    public let period: Int
    public let group: Int
    public let category: Category
    public let elementClass: ElementClass
    public let oxidationStates: [Int]
    public let electronConfiguration: String
    public let computedAtomicMass: Double?

    public var atomicNumber: Int { raw.atomicNumber }
    public var symbol: String { raw.symbol }
    public var name: String { raw.name }
    public var massNumber: Int { raw.massNumber }
    public var atomicMass: Double { raw.atomicMass }

    public init(raw: RawElement) throws {
        let z = raw.atomicNumber
        self.raw = raw
        self.block = try ChemCore.block(z)
        self.period = try ChemCore.period(z)
        self.group = try ChemCore.group(z)
        self.category = try ChemCore.category(z)
        self.elementClass = try ChemCore.elementClass(z)
        self.oxidationStates = try ChemCore.oxidationStates(z)
        self.electronConfiguration = try ChemCore.electronConfiguration(z).description
        self.computedAtomicMass = atomicMassFromIsotopes(raw.isotopes)
    }
}
