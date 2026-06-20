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
}
