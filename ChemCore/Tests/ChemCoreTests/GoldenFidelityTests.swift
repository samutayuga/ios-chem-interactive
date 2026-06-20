import XCTest
@testable import ChemCore

private struct Golden: Decodable {
    let atomic_number: Int
    let symbol: String
    let group: Int
    let period: Int
    let block: String
    let category: String
    let `class`: String
    let oxidation_states: [Int]
    let electron_configuration: String
    let computed_atomic_mass: Double?
}

final class GoldenFidelityTests: XCTestCase {
    func test_allDerivedFieldsMatchWasm() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "elements.golden", withExtension: "json"))
        let golden = try JSONDecoder().decode([Golden].self, from: Data(contentsOf: url))
        XCTAssertEqual(golden.count, 118)

        let pt = try PeriodicTable.load()
        for g in golden {
            let e = try XCTUnwrap(pt.byAtomicNumber(g.atomic_number), "z=\(g.atomic_number)")
            let ctx = "\(g.symbol) (z=\(g.atomic_number))"
            XCTAssertEqual(e.symbol, g.symbol, ctx)
            XCTAssertEqual(e.group, g.group, ctx)
            XCTAssertEqual(e.period, g.period, ctx)
            XCTAssertEqual(e.block.rawValue, g.block, ctx)
            XCTAssertEqual(e.category.rawValue, g.category, ctx)
            XCTAssertEqual(e.elementClass.rawValue, g.class, ctx)
            XCTAssertEqual(e.oxidationStates, g.oxidation_states, ctx)
            XCTAssertEqual(e.electronConfiguration, g.electron_configuration, ctx)
            if let expected = g.computed_atomic_mass {
                XCTAssertEqual(try XCTUnwrap(e.computedAtomicMass, ctx), expected, accuracy: 1e-6, ctx)
            }
        }
    }
}
