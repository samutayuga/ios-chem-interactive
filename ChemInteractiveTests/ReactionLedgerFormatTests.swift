// ChemInteractiveTests/ReactionLedgerFormatTests.swift
import XCTest
import ChemCore
@testable import ChemInteractive

final class ReactionLedgerFormatTests: XCTestCase {
    private func solved(_ z1: [(String, Bool)], _ z2: [(String, Bool)],
                        q1: ReactantEntry? = nil, q2: ReactantEntry? = nil,
                        picks: [Int] = []) -> Result<ReactionResult, ReactionError>? {
        let m = ReactionLabModel()
        // `place` blocks while a charge is pending (in either zone), so a transition
        // metal's charge must be resolved immediately after it's placed — before the
        // next token (in either zone) can go in. Interleave picks accordingly rather
        // than batching all placements before all picks.
        var pending = picks
        func place(_ s: String, _ p: Bool, zone: Int) {
            m.place(TokenTransfer(symbol: s, isPolyatomic: p), inZone: zone)
            if m.pendingCharge != nil, !pending.isEmpty {
                m.pickCharge(pending.removeFirst())
            }
        }
        for (s, p) in z1 { place(s, p, zone: 1) }
        for (s, p) in z2 { place(s, p, zone: 2) }
        if let q1 { m.setQuantity(q1, zone: 1) }
        if let q2 { m.setQuantity(q2, zone: 2) }
        return m.result
    }

    func test_classLabel() {
        XCTAssertEqual(ReactionLedgerFormat.classLabel(.doubleDisplacement), "Double displacement")
        XCTAssertEqual(ReactionLedgerFormat.classLabel(.combustion), "Combustion")
    }

    func test_equation_with_coefficients() {
        // Reactant side is fixed (r1=HCl, r2=Na₂CO₃); product ORDER is engine-defined,
        // so assert the LHS exactly and the product terms order-independently.
        let res = solved([("H", false), ("Cl", false)], [("Na", false), ("CO₃", true)])!
        guard case .success(let r) = res else { return XCTFail() }
        let eqn = ReactionLedgerFormat.equation(r)
        XCTAssertTrue(eqn.hasPrefix("2HCl + Na₂CO₃ → "), eqn)
        XCTAssertTrue(eqn.contains("2NaCl"), eqn)
        XCTAssertTrue(eqn.contains("CO₂"), eqn)
        XCTAssertTrue(eqn.contains("H₂O"), eqn)
    }

    func test_productLines_and_footer() {
        let res = solved([("Na", false), ("OH", true)], [("H", false), ("Cl", false)],
                         q1: ReactantEntry(value: 2, unit: .mole),
                         q2: ReactantEntry(value: 1, unit: .mole))!
        guard case .success(let r) = res else { return XCTFail() }
        let lines = ReactionLedgerFormat.productLines(r)
        XCTAssertTrue(lines.contains { $0.hasPrefix("1 NaCl — 1.00 mol") })
        XCTAssertTrue(ReactionLedgerFormat.footer(r).contains("limiting: HCl"))
        XCTAssertTrue(ReactionLedgerFormat.footer(r).contains("NaOH excess 1.00 mol"))
    }

    func test_outcome_noReaction() {
        let res = solved([("Cu", false)], [("Zn", false), ("SO₄", true)], picks: [2, 2])!
        guard case .noReaction(let msg)? = ReactionLedgerFormat.outcome(res) else { return XCTFail() }
        XCTAssertTrue(msg.contains("activity series"))
    }

    func test_outcome_notClassified() {
        let res = solved([("C", false), ("O", false)], [("C", false), ("H", false)])!
        guard case .notClassified? = ReactionLedgerFormat.outcome(res) else { return XCTFail() }
    }

    func test_redox_badge_and_agents_for_displacement() {
        // Zn + CuSO₄ → ZnSO₄ + Cu (both metals are transition → charge picks 2,2)
        let res = solved([("Zn", false)], [("Cu", false), ("SO₄", true)], picks: [2, 2])!
        guard case .success(let r) = res else { return XCTFail() }
        let a = analyzeRedox(r)
        XCTAssertEqual(ReactionLedgerFormat.redoxBadge(a), "Redox")
        XCTAssertEqual(ReactionLedgerFormat.redoxAgents(a), "Oxidising: CuSO₄ · Reducing: Zn")
    }

    func test_redox_badge_and_agents_for_neutralisation() {
        let res = solved([("Na", false), ("OH", true)], [("H", false), ("Cl", false)])!
        guard case .success(let r) = res else { return XCTFail() }
        let a = analyzeRedox(r)
        XCTAssertEqual(ReactionLedgerFormat.redoxBadge(a), "Non-redox")
        XCTAssertNil(ReactionLedgerFormat.redoxAgents(a))
    }
}
