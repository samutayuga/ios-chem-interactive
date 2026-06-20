import XCTest
import SwiftUI
import ChemCore
@testable import ChemInteractive

final class ThemeTests: XCTestCase {
    private func rgb(_ color: Color) -> (r: Int, g: Int, b: Int) {
        let c = UIColor(color).cgColor
        let comps = c.components ?? [0, 0, 0, 1]
        return (Int((comps[0] * 255).rounded()), Int((comps[1] * 255).rounded()), Int((comps[2] * 255).rounded()))
    }

    private func assertRGB(_ color: Color, _ r: Int, _ g: Int, _ b: Int,
                           file: StaticString = #file, line: UInt = #line) {
        let got = rgb(color)
        XCTAssertEqual(got.r, r, "red",   file: file, line: line)
        XCTAssertEqual(got.g, g, "green", file: file, line: line)
        XCTAssertEqual(got.b, b, "blue",  file: file, line: line)
    }

    func test_hexInit() {
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).r, 0x1a)
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).g, 0x0a)
        XCTAssertEqual(rgb(Color(hex: 0x1a0a2e)).b, 0x2e)
    }

    func test_brandColors() {
        assertRGB(Theme.cation, 0x00, 0xff, 0x88)
        assertRGB(Theme.anion,  0xff, 0x40, 0x80)
        assertRGB(Theme.accent, 0x70, 0x40, 0xff)
    }

    func test_categoryAndClassColors() {
        assertRGB(categoryColor(.nobleGas),        0xc8, 0xaa, 0xff)   // lavender
        assertRGB(categoryColor(.transitionMetal), 0xe8, 0xb8, 0x4b)
        assertRGB(elementClassColor(.metal),       0xff, 0xa0, 0x40)
        assertRGB(elementClassColor(.nonMetal),    0x50, 0xd8, 0xf0)
    }

    func test_bondHints() {
        // Noble gas token is always disabled regardless of placed element.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .nobleGas), BondHintKind.none)
        // Polyatomic placed → everything ionic.
        XCTAssertEqual(bondHint(firstClass: .nonMetal, firstIsPolyatomic: true, tokenClass: .nonMetal, tokenCategory: .halogen), .ionic)
        // Metal + metal → metallic.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .metal, tokenCategory: .alkaliMetal), .metallic)
        // Nonmetal + nonmetal → covalent.
        XCTAssertEqual(bondHint(firstClass: .nonMetal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .reactiveNonmetal), .covalent)
        // Metalloid pairs → covalent.
        XCTAssertEqual(bondHint(firstClass: .metalloid, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .reactiveNonmetal), .covalent)
        // Metal + nonmetal → ionic.
        XCTAssertEqual(bondHint(firstClass: .metal, firstIsPolyatomic: false, tokenClass: .nonMetal, tokenCategory: .halogen), .ionic)
    }
}
