import XCTest
import ChemCore
@testable import ChemInteractive

final class ReactionLabModelTests: XCTestCase {
    private func token(_ symbol: String, poly: Bool = false) -> TokenTransfer {
        TokenTransfer(symbol: symbol, isPolyatomic: poly)
    }

    func test_neutralisation_feasible() {
        let m = ReactionLabModel()
        m.place(token("Na"), inZone: 1); m.place(token("OH", poly: true), inZone: 1)
        m.place(token("H"), inZone: 2);  m.place(token("Cl"), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .doubleDisplacement)
        XCTAssertTrue(r.feasible)
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "H₂O"])
    }

    func test_carbonate_three_products() {
        let m = ReactionLabModel()
        m.place(token("H"), inZone: 1); m.place(token("Cl"), inZone: 1)
        m.place(token("Na"), inZone: 2); m.place(token("CO₃", poly: true), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(Set(r.products.map(\.formula)), ["NaCl", "CO₂", "H₂O"])
    }

    func test_combustion() {
        let m = ReactionLabModel()
        m.place(token("C"), inZone: 1); m.place(token("H"), inZone: 1)
        m.place(token("O"), inZone: 2)
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.reactionClass, .combustion)
    }

    func test_not_classified() {
        let m = ReactionLabModel()
        m.place(token("C"), inZone: 1); m.place(token("O"), inZone: 1)   // CO₂
        m.place(token("C"), inZone: 2); m.place(token("H"), inZone: 2)   // CH₄
        guard case .failure(let e)? = m.result else { return XCTFail("expected failure") }
        XCTAssertEqual(e, .unknownReactionClass)
    }

    func test_transition_metal_pending_blocks_result() {
        let m = ReactionLabModel()
        m.place(token("Cu"), inZone: 1); m.place(token("SO₄", poly: true), inZone: 1)
        m.place(token("Zn"), inZone: 2)
        XCTAssertNotNil(m.pendingCharge)      // Cu awaits a charge
        XCTAssertNil(m.result)
    }

    func test_single_displacement_infeasible_with_message() {
        let m = ReactionLabModel()
        m.place(token("Cu"), inZone: 1); m.pickCharge(2)                 // free Cu²⁺
        m.place(token("Zn"), inZone: 2); m.pickCharge(2)
        m.place(token("SO₄", poly: true), inZone: 2)                     // ZnSO₄
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertFalse(r.feasible)
        XCTAssertTrue(r.messages.contains { $0.contains("activity series") })
    }

    func test_yield_limiting_excess() {
        let m = ReactionLabModel()
        m.place(token("Na"), inZone: 1); m.place(token("OH", poly: true), inZone: 1)
        m.place(token("H"), inZone: 2);  m.place(token("Cl"), inZone: 2)
        m.setQuantity(ReactantEntry(value: 2, unit: .mole), zone: 1)     // 2 mol NaOH
        m.setQuantity(ReactantEntry(value: 1, unit: .mole), zone: 2)     // 1 mol HCl
        guard case .success(let r)? = m.result else { return XCTFail("expected success") }
        XCTAssertEqual(r.limiting, .b)
        XCTAssertEqual(r.excess.moles, 1.0, accuracy: 1e-6)
        let naclIdx = r.products.firstIndex { $0.formula == "NaCl" }!
        XCTAssertEqual(r.yields[naclIdx].moles, 1.0, accuracy: 1e-6)
    }

    func test_removing_sibling_keeps_pending_on_transition_metal() {
        let m = ReactionLabModel()
        m.place(token("Cu"), inZone: 1)               // Cu is a transition metal → pending (1,0)
        XCTAssertEqual(m.pendingCharge, ReactionLabModel.PendingCharge(zone: 1, index: 0))
        m.pickCharge(2)                               // resolve Cu
        XCTAssertNil(m.pendingCharge)
        m.place(token("Na"), inZone: 1)               // Cu(0), Na(1)
        m.place(token("Zn"), inZone: 2)               // Zn transition → pending (2,0)
        XCTAssertEqual(m.pendingCharge, ReactionLabModel.PendingCharge(zone: 2, index: 0))
        m.removeToken(zone: 1, index: 1)              // remove Na (a resolved sibling zone); Zn still unresolved
        XCTAssertEqual(m.pendingCharge, ReactionLabModel.PendingCharge(zone: 2, index: 0))
    }
}
