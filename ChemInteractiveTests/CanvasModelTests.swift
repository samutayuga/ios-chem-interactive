import XCTest
import ChemCore
@testable import ChemInteractive

final class CanvasModelTests: XCTestCase {
    func test_loadsAllElementsAndIons() {
        let model = CanvasModel()
        XCTAssertEqual(model.elements.count, 118)
        XCTAssertEqual(model.polyatomicIons.count, 6)
        XCTAssertEqual(model.state, .initial)
    }

    func test_resolvesElementToken() throws {
        let model = CanvasModel()
        let zone = try XCTUnwrap(model.zoneState(for: TokenTransfer(symbol: "Na", isPolyatomic: false)))
        XCTAssertEqual(zone.symbol, "Na")
        XCTAssertEqual(zone.elementClass, .metal)
        XCTAssertFalse(zone.isPolyatomic)
    }

    func test_resolvesPolyatomicToken() throws {
        let model = CanvasModel()
        let zone = try XCTUnwrap(model.zoneState(for: TokenTransfer(symbol: "OH", isPolyatomic: true)))
        XCTAssertEqual(zone.symbol, "OH")
        XCTAssertTrue(zone.isPolyatomic)
        XCTAssertEqual(zone.oxidationStates, [-1])
    }

    func test_unknownTokenResolvesNil() {
        let model = CanvasModel()
        XCTAssertNil(model.zoneState(for: TokenTransfer(symbol: "Xx", isPolyatomic: false)))
    }

    func test_placeDrivesReducer() {
        let model = CanvasModel()
        model.place(TokenTransfer(symbol: "Na", isPolyatomic: false), in: .a)
        XCTAssertEqual(model.state.canvasPhase, .slotAFilled)
        XCTAssertEqual(model.state.slotA?.symbol, "Na")
    }

    func test_naClGoesIonicAndExplains() {
        let model = CanvasModel()
        model.place(TokenTransfer(symbol: "Na", isPolyatomic: false), in: .a)
        model.place(TokenTransfer(symbol: "Cl", isPolyatomic: false), in: .b)
        XCTAssertEqual(model.state.bondingType, .ionic)
        XCTAssertEqual(model.state.canvasPhase, .explaining)
    }

    func test_selectionToggles() {
        let model = CanvasModel()
        let na = TokenTransfer(symbol: "Na", isPolyatomic: false)
        model.select(na)
        XCTAssertEqual(model.selectedToken, na)
        model.clearSelection()
        XCTAssertNil(model.selectedToken)
    }
}
