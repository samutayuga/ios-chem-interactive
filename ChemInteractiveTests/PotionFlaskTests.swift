import XCTest
import SwiftUI
@testable import ChemInteractive

final class PotionFlaskTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 200)

    func test_flaskPathStaysWithinRect() {
        let path = PotionFlaskShape().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_flaskBulbWiderThanNeck() {
        // The bulb (lower body) must be wider than the neck (upper body) — that
        // contrast is what reads as a round-bottom flask rather than a tube.
        let path = PotionFlaskShape().path(in: rect)
        let neckW = path.width(in: CGRect(x: 0, y: 0, width: 100, height: 80))
        let bulbW = path.width(in: CGRect(x: 0, y: 100, width: 100, height: 100))
        XCTAssertGreaterThan(bulbW, neckW)
    }

    func test_waveTopFillStaysWithinRect() {
        let path = WaveTop(fill: 0.6).path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_waveTopHigherFillIsTaller() {
        let low = WaveTop(fill: 0.3).path(in: rect).boundingRect.height
        let high = WaveTop(fill: 0.8).path(in: rect).boundingRect.height
        XCTAssertGreaterThan(high, low)
    }
}

private extension Path {
    /// Width of this path clipped to `region` (0 if no overlap).
    func width(in region: CGRect) -> CGFloat {
        intersection(Path(region)).boundingRect.width
    }
}
