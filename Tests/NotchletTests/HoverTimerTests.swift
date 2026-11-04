import XCTest
@testable import Notchlet

final class HoverTimerTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    func testOpensOnlyAfterDelay() {
        var timer = HoverTimer()
        XCTAssertFalse(timer.update(isInside: true, now: start, delay: 0.3))
        XCTAssertFalse(timer.update(isInside: true, now: start + 0.2, delay: 0.3))
        XCTAssertTrue(timer.update(isInside: true, now: start + 0.3, delay: 0.3))
    }

    func testLeavingZoneRestartsDelay() {
        var timer = HoverTimer()
        XCTAssertFalse(timer.update(isInside: true, now: start, delay: 0.3))
        XCTAssertFalse(timer.update(isInside: false, now: start + 0.2, delay: 0.3))
        XCTAssertFalse(timer.update(isInside: true, now: start + 0.3, delay: 0.3))
    }

    func testZeroDelayOpensImmediately() {
        var timer = HoverTimer()
        XCTAssertTrue(timer.update(isInside: true, now: start, delay: 0))
    }
}
