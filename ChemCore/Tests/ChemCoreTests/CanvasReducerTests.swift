import XCTest
@testable import ChemCore

final class CanvasReducerTests: XCTestCase {
    private func metal(_ s: String, oxidation: [Int] = [1], transition: Bool = false) -> ZoneState {
        ZoneState(symbol: s, elementClass: .metal, isPolyatomic: false, isTransition: transition,
                  valenceElectrons: 1, oxidationStates: oxidation)
    }
    private func nonmetal(_ s: String, oxidation: [Int] = [-1]) -> ZoneState {
        ZoneState(symbol: s, elementClass: .nonMetal, isPolyatomic: false, isTransition: false,
                  valenceElectrons: 7, oxidationStates: oxidation)
    }

    func test_firstDrop_goesToSlotAFilled() {
        let s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
        XCTAssertEqual(s.slotA?.symbol, "Na")
        XCTAssertNil(s.bondingType)
    }

    func test_ionic_autoIonizesBothSlots() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na", oxidation: [1])))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl", oxidation: [-1])))
        XCTAssertEqual(s.bondingType, .ionic)
        XCTAssertEqual(s.canvasPhase, .explaining)
        XCTAssertEqual(s.slotA?.status, .ionized)
        XCTAssertEqual(s.slotA?.derivedCharge, 1)
        XCTAssertEqual(s.slotB?.status, .ionized)
        XCTAssertEqual(s.slotB?.derivedCharge, -1)
    }

    func test_ionic_transitionMetalDeduces() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Fe", oxidation: [2, 3], transition: true)))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        XCTAssertEqual(s.bondingType, .ionic)
        XCTAssertEqual(s.slotA?.status, .deducing)
        // dismiss is blocked while a slot is still deducing
        let blocked = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(blocked.canvasPhase, .explaining)
        // pick charge, then dismiss advances to crossover
        let picked = canvasReducer(s, .pickTMCharge(slot: .a, charge: 3))
        XCTAssertEqual(picked.slotA?.status, .ionized)
        XCTAssertEqual(picked.slotA?.derivedCharge, 3)
        let advanced = canvasReducer(picked, .dismissExplanation)
        XCTAssertEqual(advanced.canvasPhase, .animatingCrossover)
    }

    func test_covalent_goesToExplainingThenShowing() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: nonmetal("H")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        XCTAssertEqual(s.bondingType, .covalent)
        XCTAssertEqual(s.canvasPhase, .explaining)
        let shown = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(shown.canvasPhase, .showingCovalent)
    }

    func test_metallic_goesToShowing() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: metal("Mg")))
        XCTAssertEqual(s.bondingType, .metallic)
        let shown = canvasReducer(s, .dismissExplanation)
        XCTAssertEqual(shown.canvasPhase, .showingMetallic)
    }

    func test_dropOnBothFilled_clearsOtherAndRestarts() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .dropElement(slot: .a, zone: metal("K")))
        XCTAssertEqual(s.slotA?.symbol, "K")
        XCTAssertNil(s.slotB)
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
        XCTAssertNil(s.bondingType)
    }

    func test_replaceElement_resetsOtherToNeutral() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .replaceElement(slot: .a))
        XCTAssertNil(s.slotA)
        XCTAssertEqual(s.slotB?.status, .neutral)
        XCTAssertNil(s.slotB?.derivedCharge)
        XCTAssertEqual(s.canvasPhase, .slotAFilled)
    }

    func test_crossoverCompleteAndReset() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl")))
        s = canvasReducer(s, .dismissExplanation)   // -> animatingCrossover
        s = canvasReducer(s, .crossoverComplete)
        XCTAssertEqual(s.canvasPhase, .complete)
        let r = canvasReducer(s, .reset)
        XCTAssertEqual(r, .initial)
    }

    func test_startStoichiometry_fromComplete() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na", oxidation: [1])))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("Cl", oxidation: [-1])))
        s = canvasReducer(s, .dismissExplanation)   // -> animatingCrossover
        s = canvasReducer(s, .crossoverComplete)     // -> complete
        XCTAssertEqual(s.canvasPhase, .complete)
        let stoich = canvasReducer(s, .startStoichiometry)
        XCTAssertEqual(stoich.canvasPhase, .stoichiometry)
        XCTAssertEqual(stoich.slotA?.symbol, "Na")   // reactants preserved
        XCTAssertEqual(stoich.slotB?.symbol, "Cl")
        XCTAssertEqual(stoich.bondingType, .ionic)
    }

    func test_startStoichiometry_ignoredBeforeComplete() {
        let s = canvasReducer(.initial, .dropElement(slot: .a, zone: metal("Na")))
        let same = canvasReducer(s, .startStoichiometry)
        XCTAssertEqual(same.canvasPhase, .slotAFilled)   // no-op
    }

    func test_startStoichiometry_fromShowingCovalent() {
        var s = canvasReducer(.initial, .dropElement(slot: .a, zone: nonmetal("H", oxidation: [1])))
        s = canvasReducer(s, .dropElement(slot: .b, zone: nonmetal("O", oxidation: [-2])))
        XCTAssertEqual(s.bondingType, .covalent)
        s = canvasReducer(s, .dismissExplanation)            // -> showingCovalent
        XCTAssertEqual(s.canvasPhase, .showingCovalent)
        let stoich = canvasReducer(s, .startStoichiometry)
        XCTAssertEqual(stoich.canvasPhase, .stoichiometry)
        XCTAssertEqual(stoich.slotA?.symbol, "H")
        XCTAssertEqual(stoich.bondingType, .covalent)
    }
}
