import Foundation

extension Isotope: Decodable {
    enum CodingKeys: String, CodingKey { case massNumber, relativeMass, abundance }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            massNumber: try c.decode(Int.self, forKey: .massNumber),
            relativeMass: try c.decode(Double.self, forKey: .relativeMass),
            abundance: try c.decode(Double.self, forKey: .abundance)
        )
    }
}

extension StateOfMatter: Decodable {}

public struct RawElement: Decodable, Equatable {
    public let atomicNumber: Int
    public let name: String
    public let symbol: String
    public let atomicMass: Double
    public let massNumber: Int
    public let meltingPoint: Double?
    public let boilingPoint: Double?
    public let density: Double?
    public let electronegativity: Double?
    public let state: StateOfMatter
    public let discoveryYear: Int?
    public let discoverer: String?
    public let isotopes: [Isotope]

    public static func decodeAll(from data: Data) throws -> [RawElement] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([RawElement].self, from: data)
    }

    /// Loads all elements from the bundled elements.raw.json shipped with
    /// the ChemCore module. Uses Bundle.module so the lookup is anchored to
    /// ChemCore's own resource bundle (not the caller's bundle).
    public static func loadAll() throws -> [RawElement] {
        guard let url = Bundle.module.url(forResource: "elements.raw", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        return try decodeAll(from: data)
    }
}
