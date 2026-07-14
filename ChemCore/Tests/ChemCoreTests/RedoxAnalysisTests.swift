import XCTest
@testable import ChemCore

final class RedoxAnalysisTests: XCTestCase {
    private func term(_ coeff: Int, _ formula: String, _ comp: [String: Int]) -> BalancedTerm {
        BalancedTerm(coeff: coeff, formula: formula, molarMass: 0, composition: comp)
    }
    private func result(_ reactants: [BalancedTerm], _ products: [BalancedTerm],
                        feasible: Bool = true) -> ReactionResult {
        ReactionResult(reactionClass: .singleDisplacement, reactants: reactants, products: products,
                       limiting: .both, yields: [], excess: AmountResult(moles: 0, mass: 0),
                       messages: [], feasible: feasible)
    }

    func test_synthesis_is_redox() {
        let r = result([term(2, "Na", ["Na": 1]), term(1, "Cl₂", ["Cl": 2])],
                       [term(2, "NaCl", ["Na": 1, "Cl": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "Na")     // Na 0 → +1 (oxidised)
        XCTAssertEqual(a.oxidisingAgent, "Cl₂")   // Cl 0 → −1 (reduced)
        XCTAssertEqual(Set(a.changes.map(\.symbol)), ["Na", "Cl"])
    }

    func test_single_displacement_agents() {
        let r = result([term(1, "Zn", ["Zn": 1]), term(1, "CuSO₄", ["Cu": 1, "S": 1, "O": 4])],
                       [term(1, "ZnSO₄", ["Zn": 1, "S": 1, "O": 4]), term(1, "Cu", ["Cu": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "Zn")
        XCTAssertEqual(a.oxidisingAgent, "CuSO₄")
        let zn = a.changes.first { $0.symbol == "Zn" }!
        XCTAssertEqual([zn.before, zn.after], [0, 2])
        XCTAssertFalse(a.changes.contains { $0.symbol == "S" || $0.symbol == "O" }) // unchanged
    }

    func test_combustion_is_redox() {
        let r = result([term(1, "CH₄", ["C": 1, "H": 4]), term(2, "O₂", ["O": 2])],
                       [term(1, "CO₂", ["C": 1, "O": 2]), term(2, "H₂O", ["H": 2, "O": 1])])
        let a = analyzeRedox(r)
        XCTAssertTrue(a.isRedox)
        XCTAssertEqual(a.reducingAgent, "CH₄")    // C −4 → +4
        XCTAssertEqual(a.oxidisingAgent, "O₂")    // O 0 → −2
    }

    func test_neutralisation_is_non_redox() {
        let r = result([term(1, "NaOH", ["Na": 1, "O": 1, "H": 1]), term(1, "HCl", ["H": 1, "Cl": 1])],
                       [term(1, "NaCl", ["Na": 1, "Cl": 1]), term(1, "H₂O", ["H": 2, "O": 1])])
        let a = analyzeRedox(r)
        XCTAssertFalse(a.isRedox)
        XCTAssertNil(a.oxidisingAgent)
        XCTAssertNil(a.reducingAgent)
        XCTAssertTrue(a.changes.isEmpty)
        XCTAssertEqual(a.narrative, ["This is a non-redox reaction — no oxidation states change."])
    }

    func test_infeasible_is_empty() {
        let r = result([term(1, "Cu", ["Cu": 1])], [], feasible: false)
        let a = analyzeRedox(r)
        XCTAssertFalse(a.isRedox)
        XCTAssertTrue(a.changes.isEmpty && a.narrative.isEmpty)
    }

    func test_narrative_and_name_closure() {
        let r = result([term(1, "Zn", ["Zn": 1]), term(1, "CuSO₄", ["Cu": 1, "S": 1, "O": 4])],
                       [term(1, "ZnSO₄", ["Zn": 1, "S": 1, "O": 4]), term(1, "Cu", ["Cu": 1])])
        let a = analyzeRedox(r) { $0 == "CuSO₄" ? "copper(II) sulfate" : nil }
        // A per-element line uses signed states and the substituted name.
        XCTAssertTrue(a.narrative.contains { $0.contains("Zn is oxidised") && $0.contains("from 0 in Zn to +2 in ZnSO₄") })
        XCTAssertTrue(a.narrative.contains { $0.contains("copper(II) sulfate is the oxidising agent") })
    }

    func test_conflicting_same_side_states_go_to_indeterminate() {
        // O appears at 0 (in O₂) and −2 (in H₂O) on the reactant side → ambiguous, must be flagged.
        let r = result([term(1, "O₂", ["O": 2]), term(1, "H₂O", ["H": 2, "O": 1])],
                       [term(1, "H₂O", ["H": 2, "O": 1])])
        let a = analyzeRedox(r)
        XCTAssertFalse(a.changes.contains { $0.symbol == "O" })   // O skipped, not in changes
        XCTAssertTrue(a.indeterminate.contains("O₂"))
        XCTAssertTrue(a.indeterminate.contains("H₂O"))
        XCTAssertEqual(a.indeterminate.count, Set(a.indeterminate).count) // de-duplicated
    }
}
