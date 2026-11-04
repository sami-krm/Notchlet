import XCTest
@testable import DynamicNotch

@MainActor
final class BluetoothTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    /// Reprend le format réel observé : valeurs avec espace insécable.
    private let sample = """
    {"SPBluetoothDataType":[{
      "device_connected":[{"AirPods Pro":{
        "device_address":"AA:BB:CC:DD:EE:FF",
        "device_batteryLevelLeft":"80\u{00A0}%",
        "device_batteryLevelRight":"65\u{00A0}%",
        "device_minorType":"Headphones"
      }},{"Clavier":{
        "device_address":"11:22:33:44:55:66",
        "device_batteryLevelMain":"42 %",
        "device_minorType":"Keyboard"
      }}],
      "device_not_connected":[{"Ancien":{"device_address":"99:99:99:99:99:99"}}]
    }]}
    """

    func testReadsEarbudsBatteryWithNonBreakingSpace() throws {
        let report = try XCTUnwrap(BluetoothDeviceReport.parse(Data(sample.utf8), address: "AA:BB:CC:DD:EE:FF"))
        XCTAssertEqual(report.battery.left, 80)
        XCTAssertEqual(report.battery.right, 65)
        XCTAssertEqual(report.minorType, "Headphones")
    }

    func testMatchesIOBluetoothAddressFormat() throws {
        let report = try XCTUnwrap(BluetoothDeviceReport.parse(Data(sample.utf8), address: "11-22-33-44-55-66"))
        XCTAssertEqual(report.battery.main, 42)
    }

    func testIgnoresDisconnectedAndUnknownDevices() {
        XCTAssertNil(BluetoothDeviceReport.parse(Data(sample.utf8), address: "99:99:99:99:99:99"))
        XCTAssertNil(BluetoothDeviceReport.parse(Data("pas du json".utf8), address: "AA:BB:CC:DD:EE:FF"))
    }

    func testDisplaysWeakestEarbudOrMainLevel() {
        XCTAssertEqual(BluetoothBattery(left: 80, right: 65).displayed, 65)
        XCTAssertEqual(BluetoothBattery(left: 80).displayed, 80)
        XCTAssertEqual(BluetoothBattery(main: 42).displayed, 42)
        XCTAssertNil(BluetoothBattery(boxCase: 90).displayed)
    }

    func testSymbolFollowsModelAndType() {
        XCTAssertEqual(BluetoothActivity.symbol(name: "AirPods Pro de Sami", minorType: "Headphones"), "airpodspro")
        XCTAssertEqual(BluetoothActivity.symbol(name: "AirPods Max", minorType: "Headphones"), "airpodsmax")
        XCTAssertEqual(BluetoothActivity.symbol(name: "AirPods", minorType: "Headphones"), "airpods")
        XCTAssertEqual(BluetoothActivity.symbol(name: "Casque", minorType: "Headset"), "headphones")
        XCTAssertEqual(BluetoothActivity.symbol(name: "Enceinte", minorType: "Speaker"), "hifispeaker.fill")
        XCTAssertEqual(BluetoothActivity.symbol(name: "Inconnu", minorType: nil), "dot.radiowaves.left.and.right")
    }

    func testEverySymbolExistsOnThisSystem() {
        let names = ["AirPods Pro", "AirPods Max", "AirPods", "Casque"]
        for name in names {
            let symbol = BluetoothActivity.symbol(name: name, minorType: "Headphones")
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), symbol)
        }
        for type in ["Speaker", "Keyboard", "Mouse", "Autre"] {
            let symbol = BluetoothActivity.symbol(name: "Appareil", minorType: type)
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), symbol)
        }
    }

    func testFilterIgnoresDevicesAlreadyConnectedAtStart() {
        var filter = BluetoothAlertFilter(startedAt: start)
        XCTAssertFalse(filter.shouldAlert(address: "A", now: start + 1))
        XCTAssertTrue(filter.shouldAlert(address: "A", now: start + 3))
    }

    func testFilterIgnoresQuickReconnections() {
        var filter = BluetoothAlertFilter(startedAt: start)
        XCTAssertTrue(filter.shouldAlert(address: "A", now: start + 10))
        XCTAssertFalse(filter.shouldAlert(address: "A", now: start + 20))
        XCTAssertTrue(filter.shouldAlert(address: "B", now: start + 20))
        XCTAssertTrue(filter.shouldAlert(address: "A", now: start + 30))
    }
}
