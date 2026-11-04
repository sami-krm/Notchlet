import AppKit
import XCTest
@testable import DynamicNotch

final class MusicTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Progression

    func testProgressAdvancesOnlyWhilePlaying() {
        let progress = PlaybackProgress(position: 10, duration: 100, updatedAt: start)
        XCTAssertEqual(progress.position(at: start + 5, isPlaying: true), 15)
        XCTAssertEqual(progress.position(at: start + 5, isPlaying: false), 10)
    }

    func testProgressStopsAtTrackEnd() {
        let progress = PlaybackProgress(position: 95, duration: 100, updatedAt: start)
        XCTAssertEqual(progress.position(at: start + 60, isPlaying: true), 100)
    }

    func testSeekingStaysInsideTrack() {
        let progress = PlaybackProgress(position: 10, duration: 100, updatedAt: start)
        XCTAssertEqual(progress.seeking(to: 40, at: start + 5).position(at: start + 5, isPlaying: true), 40)
        XCTAssertEqual(progress.seeking(to: -5, at: start).position, 0)
        XCTAssertEqual(progress.seeking(to: 500, at: start).position, 100)
    }

    func testParsesFrenchAndEnglishDecimals() throws {
        let french = try XCTUnwrap(MediaManager.parseProgress("12,5|180,25", isSpotify: false))
        XCTAssertEqual(french.position, 12.5)
        XCTAssertEqual(french.duration, 180.25)
        let english = try XCTUnwrap(MediaManager.parseProgress("12.5|180.25", isSpotify: false))
        XCTAssertEqual(english.duration, 180.25)
    }

    func testSpotifyDurationAcceptsSecondsAndMilliseconds() throws {
        XCTAssertEqual(try XCTUnwrap(MediaManager.parseProgress("1|240000", isSpotify: true)).duration, 240)
        XCTAssertEqual(try XCTUnwrap(MediaManager.parseProgress("1|240", isSpotify: true)).duration, 240)
    }

    func testRejectsInvalidProgress() {
        XCTAssertNil(MediaManager.parseProgress("", isSpotify: false))
        XCTAssertNil(MediaManager.parseProgress("abc|def", isSpotify: false))
        XCTAssertNil(MediaManager.parseProgress("10|0", isSpotify: false))
    }

    // MARK: - Pochette

    func testParsesArtworkData() {
        XCTAssertEqual(MediaManager.parseArtworkData("«data tdtaFFD8a0»"), Data([0xFF, 0xD8, 0xA0]))
        XCTAssertEqual(MediaManager.parseArtworkData("«data JPEG00FF»"), Data([0x00, 0xFF]))
    }

    func testRejectsInvalidArtworkData() {
        XCTAssertNil(MediaManager.parseArtworkData("https://example.com/image.jpg"))
        XCTAssertNil(MediaManager.parseArtworkData("«data tdtaF»"))
        XCTAssertNil(MediaManager.parseArtworkData("«data tdtaZZ»"))
        XCTAssertNil(MediaManager.parseArtworkData("«data tdta»"))
    }

    func testAccentColorFollowsArtwork() throws {
        let image = NSImage(size: NSSize(width: 8, height: 8), flipped: false) { rect in
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).setFill()
            rect.fill()
            return true
        }
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let color = try XCTUnwrap(MediaManager.accentColor(of: tiff)?.usingColorSpace(.sRGB))
        XCTAssertGreaterThan(color.redComponent, 0.7)
        XCTAssertLessThan(color.greenComponent, 0.3)
        XCTAssertLessThan(color.blueComponent, 0.3)
    }

    // MARK: - Balayages

    func testSwipeFollowsDominantAxis() {
        var left = SwipeDetector()
        XCTAssertEqual(left.update(fingerX: -40, fingerY: 5), .left)
        var right = SwipeDetector()
        XCTAssertEqual(right.update(fingerX: 40, fingerY: -5), .right)
        var down = SwipeDetector()
        XCTAssertEqual(down.update(fingerX: 5, fingerY: 40), .down)
        var up = SwipeDetector()
        XCTAssertEqual(up.update(fingerX: 5, fingerY: -40), .up)
    }

    func testSwipeAccumulatesThenFiresOnce() {
        var detector = SwipeDetector()
        XCTAssertNil(detector.update(fingerX: 15, fingerY: 0))
        XCTAssertEqual(detector.update(fingerX: 15, fingerY: 0), .right)
        XCTAssertNil(detector.update(fingerX: 100, fingerY: 0))
    }
}
