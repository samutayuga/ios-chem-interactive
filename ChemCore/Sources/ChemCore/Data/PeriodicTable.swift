import Foundation

public struct PeriodicTable {
    public let elements: [Element]

    public static func load() throws -> PeriodicTable {
        let raws = try RawElement.loadAll()
        let elements = try raws
            .sorted { $0.atomicNumber < $1.atomicNumber }
            .map { try Element(raw: $0) }
        return PeriodicTable(elements: elements)
    }

    public func bySymbol(_ symbol: String) -> Element? {
        elements.first { $0.symbol == symbol }
    }
    public func byAtomicNumber(_ z: Int) -> Element? {
        elements.first { $0.atomicNumber == z }
    }

    public enum DataError: Error { case missingResource }
}
