import XCTest
@testable import ChemCore

final class ValenceTests: XCTestCase {
    func test_fallback() {
        XCTAssertEqual(groupToValenceFallback(1), 1)
        XCTAssertEqual(groupToValenceFallback(2), 2)
        XCTAssertEqual(groupToValenceFallback(14), 4)
        XCTAssertEqual(groupToValenceFallback(17), 7)
        XCTAssertEqual(groupToValenceFallback(8), 0)   // transition: no fallback
    }
    func test_isTransitionMetal() {
        XCTAssertTrue(isTransitionMetal(3))
        XCTAssertTrue(isTransitionMetal(12))
        XCTAssertFalse(isTransitionMetal(2))
        XCTAssertFalse(isTransitionMetal(13))
    }
    func test_parseHighestShell() {
        // Na: 1s2 2s2 2p6 3s1 -> highest n=3 -> 1
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s1", group: 1), 1)
        // Cl: highest n=3 -> 3s2 + 3p5 = 7
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s2 3p5", group: 17), 7)
        // Fe: highest n=4 -> 4s2 = 2
        XCTAssertEqual(parseValenceElectrons(config: "1s2 2s2 2p6 3s2 3p6 3d6 4s2", group: 8), 2)
    }
    func test_stripsNobleGasPrefix() {
        XCTAssertEqual(parseValenceElectrons(config: "[Ne] 3s2 3p3", group: 15), 5)
    }
    func test_emptyFallsBackToGroup() {
        XCTAssertEqual(parseValenceElectrons(config: "", group: 16), 6)
    }
}
