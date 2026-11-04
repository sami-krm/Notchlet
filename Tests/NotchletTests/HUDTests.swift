import XCTest
@testable import Notchlet

@MainActor
final class HUDTests: XCTestCase {
    private func data1(code: Int, state: Int) -> Int { code << 16 | state << 8 }

    // MARK: - Touches

    func testDecodesMediaKeys() {
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 0, state: 0x0A))?.kind, .volumeUp)
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 1, state: 0x0A))?.kind, .volumeDown)
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 2, state: 0x0A))?.kind, .brightnessUp)
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 3, state: 0x0A))?.kind, .brightnessDown)
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 7, state: 0x0A))?.kind, .mute)
    }

    func testDistinguishesPressAndRelease() {
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 0, state: 0x0A))?.isDown, true)
        XCTAssertEqual(MediaKey(subtype: 8, data1: data1(code: 0, state: 0x0B))?.isDown, false)
    }

    func testIgnoresOtherEvents() {
        XCTAssertNil(MediaKey(subtype: 7, data1: data1(code: 0, state: 0x0A)))
        // Lecture-pause (16) reste à macOS et aux lecteurs.
        XCTAssertNil(MediaKey(subtype: 8, data1: data1(code: 16, state: 0x0A)))
        XCTAssertNil(MediaKey(subtype: 8, data1: data1(code: 0, state: 0x01)))
    }

    // MARK: - Niveaux

    func testLevelStepsAndStaysInRange() {
        XCTAssertEqual(HUDActivity.steppedLevel(0.5, up: true), 9 / 16)
        XCTAssertEqual(HUDActivity.steppedLevel(0.5, up: false), 7 / 16)
        XCTAssertEqual(HUDActivity.steppedLevel(1, up: true), 1)
        XCTAssertEqual(HUDActivity.steppedLevel(0, up: false), 0)
    }

    func testLevelSnapsToNearestStep() {
        XCTAssertEqual(HUDActivity.steppedLevel(0.51, up: true), 9 / 16)
    }

    func testSymbolFollowsLevel() {
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0).symbol, "speaker.slash.fill")
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0.8, isMuted: true).symbol, "speaker.slash.fill")
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0.2).symbol, "speaker.wave.1.fill")
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0.5).symbol, "speaker.wave.2.fill")
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0.9).symbol, "speaker.wave.3.fill")
        XCTAssertEqual(HUDActivity(kind: .brightness, level: 0.9).symbol, "sun.max.fill")
    }

    // MARK: - Affichage dans l'île

    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 200, height: 32), hasNotch: true))
    }

    func testRepeatedPressesReplaceTheSameHUD() throws {
        let vm = makeViewModel()
        vm.showImmediately(HUDActivity(kind: .volume, level: 0.25))
        vm.showImmediately(HUDActivity(kind: .volume, level: 0.5))
        XCTAssertEqual(vm.transientQueue.count, 1)
        XCTAssertEqual((vm.displayed as? HUDActivity)?.level, 0.5)
    }

    func testHUDPassesBeforeAlertWhichThenComesBack() {
        let vm = makeViewModel()
        vm.enqueue(BatteryAlertActivity(alert: .low(level: 10)))
        vm.showImmediately(HUDActivity(kind: .volume, level: 0.5))
        XCTAssertEqual(vm.displayed?.id, "hud.volume")

        vm.finishCurrentTransient()
        XCTAssertEqual(vm.displayed?.id, "battery.low")
    }

    func testDeviceNameAddsFooterHeight() {
        let vm = makeViewModel()
        vm.showImmediately(HUDActivity(kind: .volume, level: 0.5))
        let withoutDevice = vm.closedSize.height
        vm.showImmediately(HUDActivity(kind: .volume, level: 0.5, deviceName: "AirPods"))
        XCTAssertEqual(vm.closedSize.height, withoutDevice + vm.closedFooterHeight)
    }
}
