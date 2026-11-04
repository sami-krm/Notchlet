import XCTest
@testable import DynamicNotch

@MainActor
final class BatteryAlertTests: XCTestCase {
    func testPluggingInAlertsButLaunchingDoesNot() {
        var monitor = BatteryAlertMonitor()
        XCTAssertNil(monitor.update(level: 50, isPluggedIn: true, threshold: 20))
        XCTAssertNil(monitor.update(level: 51, isPluggedIn: true, threshold: 20))
        XCTAssertNil(monitor.update(level: 50, isPluggedIn: false, threshold: 20))
        XCTAssertEqual(monitor.update(level: 50, isPluggedIn: true, threshold: 20), .charging(level: 50))
    }

    func testLowAlertFiresOnceBelowThreshold() {
        var monitor = BatteryAlertMonitor()
        XCTAssertNil(monitor.update(level: 21, isPluggedIn: false, threshold: 20))
        XCTAssertEqual(monitor.update(level: 20, isPluggedIn: false, threshold: 20), .low(level: 20))
        XCTAssertNil(monitor.update(level: 19, isPluggedIn: false, threshold: 20))
    }

    func testLowAlertFiresAtLaunchIfAlreadyLow() {
        var monitor = BatteryAlertMonitor()
        XCTAssertEqual(monitor.update(level: 10, isPluggedIn: false, threshold: 20), .low(level: 10))
    }

    func testLowAlertRearmsAfterCharging() {
        var monitor = BatteryAlertMonitor()
        XCTAssertEqual(monitor.update(level: 15, isPluggedIn: false, threshold: 20), .low(level: 15))
        XCTAssertEqual(monitor.update(level: 15, isPluggedIn: true, threshold: 20), .charging(level: 15))
        XCTAssertEqual(monitor.update(level: 15, isPluggedIn: false, threshold: 20), .low(level: 15))
    }

    func testRepeatedPluggingShowsOneAlertAtATime() {
        let vm = NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 200, height: 32), hasNotch: true))
        vm.enqueue(BatteryAlertActivity(alert: .charging(level: 50)))
        vm.enqueue(BatteryAlertActivity(alert: .charging(level: 50)))
        XCTAssertEqual(vm.displayed?.id, "battery.charging")

        vm.finishCurrentTransient()
        XCTAssertNil(vm.displayed)
    }

    func testWingFollowsDisplayedActivity() {
        let vm = NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 200, height: 32), hasNotch: true))
        let emptyWidth = vm.closedSize.width
        vm.enqueue(BatteryAlertActivity(alert: .low(level: 10)))
        XCTAssertEqual(vm.closedSize.width, emptyWidth + 2 * 50)
    }
}
