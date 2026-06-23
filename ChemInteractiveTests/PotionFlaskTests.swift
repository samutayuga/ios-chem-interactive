import XCTest
import SwiftUI
@testable import ChemInteractive

final class MeasuringCylinderTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 200)

    func test_cylinderPathStaysWithinRect() {
        let path = MeasuringCylinderShape().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
    }

    func test_graduationTicksStayWithinRect() {
        let path = GraduationTicks().path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(rect.insetBy(dx: -0.5, dy: -0.5).contains(path.boundingRect))
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
