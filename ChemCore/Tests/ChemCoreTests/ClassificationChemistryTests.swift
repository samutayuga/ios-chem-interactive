import XCTest
@testable import ChemCore

final class ClassificationChemistryTests: XCTestCase {
    func test_categories() throws {
        XCTAssertEqual(try category(1), .reactiveNonmetal)     // H
        XCTAssertEqual(try category(2), .nobleGas)             // He
        XCTAssertEqual(try category(11), .alkaliMetal)         // Na
        XCTAssertEqual(try category(12), .alkalineEarthMetal)  // Mg
        XCTAssertEqual(try category(26), .transitionMetal)     // Fe
        XCTAssertEqual(try category(5), .metalloid)            // B
        XCTAssertEqual(try category(17), .halogen)             // Cl
        XCTAssertEqual(try category(13), .postTransitionMetal) // Al
        XCTAssertEqual(try category(8), .reactiveNonmetal)     // O
        XCTAssertEqual(try category(60), .lanthanide)          // Nd
        XCTAssertEqual(try category(92), .actinide)            // U
    }
    func test_elementClass() throws {
        XCTAssertEqual(try elementClass(1), .nonMetal)   // H exception
        XCTAssertEqual(try elementClass(17), .nonMetal)  // Cl (group 17)
        XCTAssertEqual(try elementClass(2), .nonMetal)   // He
        XCTAssertEqual(try elementClass(57), .metal)     // La
        XCTAssertEqual(try elementClass(92), .metal)     // U
        for z in [5, 14, 32, 33, 51, 52, 84] {
            XCTAssertEqual(try elementClass(z), .metalloid, "z=\(z)")
        }
        XCTAssertEqual(try elementClass(85), .nonMetal)  // At (group 17, not metalloid)
        XCTAssertEqual(try elementClass(6), .nonMetal)   // C
        XCTAssertEqual(try elementClass(16), .nonMetal)  // S
        XCTAssertEqual(try elementClass(34), .nonMetal)  // Se
        XCTAssertEqual(try elementClass(11), .metal)     // Na
        XCTAssertEqual(try elementClass(79), .metal)     // Au
    }
    func test_oxidationStates() throws {
        XCTAssertEqual(try oxidationStates(11), [1])        // Na
        XCTAssertEqual(try oxidationStates(12), [2])        // Mg
        XCTAssertEqual(try oxidationStates(8), [-2])        // O
        XCTAssertEqual(try oxidationStates(9), [-1])        // F
        XCTAssertEqual(try oxidationStates(10), [0])        // Ne (group 18 catch-all)
        XCTAssertEqual(try oxidationStates(5), [3])         // B
        XCTAssertEqual(try oxidationStates(6), [-4, 4])     // C
        XCTAssertEqual(try oxidationStates(7), [-3, 3, 5])  // N
        XCTAssertEqual(try oxidationStates(26), [2, 3])     // Fe
    }
}
