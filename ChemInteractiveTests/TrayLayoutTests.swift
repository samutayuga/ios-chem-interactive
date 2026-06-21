import XCTest
import CoreGraphics
@testable import ChemInteractive

final class TrayLayoutTests: XCTestCase {
    func test_heightBound_choosesHeightFit() {
        // Wide-but-short frame: height limits the cell.
        let m = trayCellMetrics(width: 2000, height: 360)
        // heightFit = (360 - 8*2)/9 = 38.22 -> floor 38; widthFit much larger.
        XCTAssertEqual(m.cell, 38)
    }

    func test_widthBound_choosesWidthFit() {
        // Narrow frame: width limits the cell.
        let m = trayCellMetrics(width: 390, height: 2000)
        // widthFit = (390 - 17*2)/18 = 19.77 -> floor 19.
        XCTAssertEqual(m.cell, 19)
    }

    func test_symbolFontTracksCell() {
        let m = trayCellMetrics(width: 2000, height: 360)
        XCTAssertEqual(m.symbolFont, 38 * 0.37, accuracy: 0.001)
    }

    func test_cornerNumbersHiddenBelowThreshold() {
        let small = trayCellMetrics(width: 390, height: 2000) // cell 19
        XCTAssertFalse(small.showCornerNumbers)
        let big = trayCellMetrics(width: 2000, height: 360)    // cell 38
        XCTAssertTrue(big.showCornerNumbers)
    }

    func test_minCellClamp() {
        let m = trayCellMetrics(width: 10, height: 10)
        XCTAssertEqual(m.cell, 18) // clamped to minCell
    }
}
