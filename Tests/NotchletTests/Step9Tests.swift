import XCTest
@testable import Notchlet

@MainActor
final class Step9Tests: XCTestCase {
    private let assertions = Data("""
    {"data":[{"storeAssertionRecords":[{"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.focus.work"}}]}]}
    """.utf8)
    private let configurations = Data("""
    {"data":[{"modeConfigurations":{"com.apple.focus.work":{"mode":{"name":"Travail","symbolImageName":"briefcase.fill"}}}}]}
    """.utf8)

    func testReadsActiveModeWithItsNameAndSymbol() {
        let mode = FocusStatus.parse(assertions: assertions, configurations: configurations)
        XCTAssertEqual(mode, FocusMode(identifier: "com.apple.focus.work", name: "Travail", symbol: "briefcase.fill"))
    }

    func testFallsBackWhenConfigurationIsMissing() {
        let mode = FocusStatus.parse(assertions: assertions, configurations: nil)
        XCTAssertEqual(mode?.name, "Concentration")
        XCTAssertEqual(mode?.symbol, "moon.fill")
    }

    func testNoActiveModeOrUnknownFormatGivesNothing() {
        XCTAssertNil(FocusStatus.parse(assertions: Data(#"{"data":[{"storeAssertionRecords":[]}]}"#.utf8), configurations: nil))
        XCTAssertNil(FocusStatus.parse(assertions: Data(#"{"data":[{}]}"#.utf8), configurations: nil))
        XCTAssertNil(FocusStatus.parse(assertions: Data("pas du json".utf8), configurations: nil))
    }

    func testAlertsOnlyOnRealChanges() {
        let manager = FocusManager()
        var changes: [FocusMode?] = []
        manager.onChange = { changes.append($0) }
        let work = FocusMode(identifier: "a", name: "Travail", symbol: "briefcase.fill")

        manager.apply(.mode(work))
        XCTAssertTrue(changes.isEmpty, "le premier relevé décrit l'état au lancement")
        manager.apply(.mode(work))
        XCTAssertTrue(changes.isEmpty)
        manager.apply(.mode(nil))
        XCTAssertEqual(changes.count, 1)
        XCTAssertNil(changes[0])
    }

    func testDeniedAccessIsReportedWithoutAlert() {
        let manager = FocusManager()
        var alerted = false
        manager.onChange = { _ in alerted = true }
        manager.apply(.denied)
        XCTAssertTrue(manager.isDenied)
        XCTAssertFalse(alerted)
        manager.apply(.mode(nil))
        XCTAssertFalse(manager.isDenied)
    }

    func testUnknownFocusSymbolFallsBack() {
        let unknown = FocusMode(identifier: "a", name: "A", symbol: "symbole.inexistant")
        XCTAssertEqual(FocusActivity(mode: unknown).symbol, "moon.fill")
        XCTAssertEqual(FocusActivity(mode: nil).symbol, "moon")
    }
}
