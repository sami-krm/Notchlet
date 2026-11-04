import SwiftUI
import XCTest
@testable import Notchlet

@MainActor
final class DesignTests: XCTestCase {
    private func makeViewModel() -> NotchViewModel {
        NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 200, height: 32), hasNotch: true))
    }

    // MARK: - Modes de lecture

    func testParsesSpotifyAndMusicModes() throws {
        let spotify = try XCTUnwrap(MediaManager.parsePlaybackModes("true|false"))
        XCTAssertTrue(spotify.shuffling)
        XCTAssertFalse(spotify.repeating)

        let music = try XCTUnwrap(MediaManager.parsePlaybackModes("false|all"))
        XCTAssertFalse(music.shuffling)
        XCTAssertTrue(music.repeating)

        XCTAssertEqual(MediaManager.parsePlaybackModes("false|off")?.repeating, false)
        XCTAssertEqual(MediaManager.parsePlaybackModes("false|one")?.repeating, true)
        XCTAssertNil(MediaManager.parsePlaybackModes("erreur"))
    }

    func testBuildsShareableSpotifyLink() {
        XCTAssertEqual(MediaManager.shareableSpotifyLink("spotify:track:abc"), "https://open.spotify.com/track/abc")
        XCTAssertEqual(MediaManager.shareableSpotifyLink("https://exemple.com"), "https://exemple.com")
    }

    // MARK: - Île

    func testVolumeControlMakesIslandTaller() {
        let vm = makeViewModel()
        let normal = vm.openSize.height
        vm.showsVolumeControl = true
        XCTAssertGreaterThan(vm.openSize.height, normal)
    }

    func testOutputSymbolFollowsDevice() {
        XCTAssertEqual(AudioOutputSymbol.symbol(deviceName: "Haut-parleurs MacBook Air"), "laptopcomputer")
        XCTAssertEqual(AudioOutputSymbol.symbol(deviceName: "AirPods Pro de Sami"), "airpodspro")
        XCTAssertEqual(AudioOutputSymbol.symbol(deviceName: "Enceinte"), "hifispeaker.fill")
        XCTAssertEqual(AudioOutputSymbol.symbol(deviceName: nil), "speaker.wave.2.fill")
    }

    func testPercentageWidensHUD() {
        XCTAssertGreaterThan(HUDActivity(kind: .volume, level: 0.5, showsPercentage: true).closedWing,
                             HUDActivity(kind: .volume, level: 0.5).closedWing)
    }

    func testDurationsComeFromSettings() {
        XCTAssertEqual(HUDActivity(kind: .volume, level: 0.5, duration: 3).displayDuration, 3)
        XCTAssertEqual(BatteryAlertActivity(alert: .low(level: 10), duration: 7).displayDuration, 7)
    }

    // MARK: - Réglages

    func testEveryPageBelongsToExactlyOneGroup() {
        let grouped = SettingsPage.groups.flatMap(\.pages)
        XCTAssertEqual(Set(grouped), Set(SettingsPage.allCases))
        XCTAssertEqual(grouped.count, SettingsPage.allCases.count)
    }

    func testEverySettingsSymbolExists() {
        let symbols = SettingsPage.allCases.map(\.symbol)
            + MusicSideButton.allCases.map(\.symbol)
            + HUDAnimationSpeed.allCases.map(\.symbol)
            + IdleActivity.allCases.map(\.symbol)
        for symbol in symbols {
            XCTAssertNotNil(NSImage(systemSymbolName: symbol, accessibilityDescription: nil), symbol)
        }
    }
}
