import AppKit
import XCTest
@testable import Notchlet

@MainActor
final class Step8Tests: XCTestCase {
    // MARK: - Météo

    func testParsesOpenMeteoResponse() {
        let json = #"{"latitude":43.6,"current":{"time":"2026-11-04T20:00","temperature_2m":17.6,"weather_code":61}}"#
        let report = WeatherReport.parse(Data(json.utf8))
        XCTAssertEqual(report, WeatherReport(temperature: 17.6, code: 61))
        XCTAssertEqual(report?.temperatureText, "18°")
        XCTAssertEqual(report?.label, "Pluie")
    }

    func testRejectsInvalidResponses() {
        XCTAssertNil(WeatherReport.parse(Data("pas du json".utf8)))
        XCTAssertNil(WeatherReport.parse(Data(#"{"error":true,"reason":"limite"}"#.utf8)))
    }

    func testPositionIsRoundedBeforeLeavingTheMac() throws {
        let url = try XCTUnwrap(WeatherAPI.url(latitude: 43.611234, longitude: 3.876789))
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "latitude" }?.value, "43.61")
        XCTAssertEqual(query.first { $0.name == "longitude" }?.value, "3.88")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertFalse(url.absoluteString.contains("43.6112"))
    }

    func testEveryWeatherSymbolExists() {
        for code in [0, 1, 3, 45, 51, 61, 71, 80, 95, 123] {
            let symbol = WeatherReport(temperature: 0, code: code).symbol
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), symbol)
        }
    }

    // MARK: - Onde sonore

    func testLevelIsZeroForSilenceAndFullForLoudSound() {
        XCTAssertEqual(AudioLevel.normalized(rms: 0), 0)
        XCTAssertEqual(AudioLevel.normalized(rms: 1), 1)
        XCTAssertEqual(AudioLevel.normalized(rms: 2), 1)
        XCTAssertEqual(AudioLevel.normalized(rms: 0.0001), 0)
    }

    func testRMSOfConstantSignal() {
        let samples: [Float] = [0.5, -0.5, 0.5, -0.5]
        samples.withUnsafeBufferPointer { XCTAssertEqual(AudioLevel.rms($0), 0.5, accuracy: 0.0001) }
        [Float]().withUnsafeBufferPointer { XCTAssertEqual(AudioLevel.rms($0), 0) }
    }

    func testNewestLevelEntersOnTheRight() {
        XCTAssertEqual(AudioLevel.pushing(0.9, into: [0.1, 0.2, 0.3, 0.4]), [0.2, 0.3, 0.4, 0.9])
    }

    // MARK: - Étagère

    func testShelfKeepsFilesOnceAndRefusesWebAddresses() throws {
        let shelf = ShelfManager()
        let file = URL(fileURLWithPath: "/tmp/document.pdf")
        shelf.add(file)
        shelf.add(file)
        shelf.add(try XCTUnwrap(URL(string: "https://exemple.com/fichier.pdf")))
        XCTAssertEqual(shelf.files, [file])

        shelf.remove(file)
        XCTAssertTrue(shelf.files.isEmpty)
    }
}
