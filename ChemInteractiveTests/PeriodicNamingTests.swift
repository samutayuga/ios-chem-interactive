import XCTest
import ChemCore
@testable import ChemInteractive

final class PeriodicNamingTests: XCTestCase {
    private func el(_ z: Int) throws -> Element {
        let pt = try PeriodicTable.load()
        return try XCTUnwrap(pt.elements.first { $0.atomicNumber == z })
    }

    func test_namedGroups() throws {
        XCTAssertEqual(periodicGroupName(for: try el(11)), "Group 1/Alkali metals")        // Na
        XCTAssertEqual(periodicGroupName(for: try el(20)), "Group 2/Alkaline earth metals") // Ca
        XCTAssertEqual(periodicGroupName(for: try el(26)), "Group 8/Transition metals")     // Fe
        XCTAssertEqual(periodicGroupName(for: try el(6)),  "Group 14/Carbon group")         // C
        XCTAssertEqual(periodicGroupName(for: try el(7)),  "Group 15/Pnictogens")           // N
        XCTAssertEqual(periodicGroupName(for: try el(8)),  "Group 16/Chalcogens")           // O
        XCTAssertEqual(periodicGroupName(for: try el(17)), "Group 17/Halogens")             // Cl
        XCTAssertEqual(periodicGroupName(for: try el(10)), "Group 18/Noble gases")          // Ne
    }

    func test_hydrogenHasNoAlkaliLabel() throws {
        XCTAssertEqual(periodicGroupName(for: try el(1)), "Group 1")                        // H
    }

    func test_fBlock() throws {
        XCTAssertEqual(periodicGroupName(for: try el(57)), "Lanthanides")  // La
        XCTAssertEqual(periodicGroupName(for: try el(92)), "Actinides")    // U
    }
}
