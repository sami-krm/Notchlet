import XCTest
@testable import Notchlet

final class CallTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    func testShortMicUseIsNotACall() {
        var tracker = MicUseTracker()
        XCTAssertNil(tracker.update(isInUse: true, now: start))
        XCTAssertNil(tracker.update(isInUse: true, now: start + 3))
        XCTAssertNil(tracker.update(isInUse: false, now: start + 4))
        XCTAssertNil(tracker.update(isInUse: true, now: start + 5))
    }

    func testSustainedMicUseStartsACallFromItsBeginning() {
        var tracker = MicUseTracker()
        XCTAssertNil(tracker.update(isInUse: true, now: start))
        XCTAssertEqual(tracker.update(isInUse: true, now: start + 4), start)
        XCTAssertEqual(tracker.update(isInUse: true, now: start + 60), start)
        XCTAssertNil(tracker.update(isInUse: false, now: start + 61))
    }

    func testDetectsCallBannerInFrenchAndEnglish() {
        XCTAssertEqual(IncomingCallDetector.detect(texts: ["Camille", "FaceTime"], buttons: ["Refuser", "Accepter"]),
                       IncomingCall(caller: "Camille"))
        XCTAssertEqual(IncomingCallDetector.detect(texts: ["Alex"], buttons: ["Decline", "Answer"]),
                       IncomingCall(caller: "Alex"))
    }

    func testIgnoresOrdinaryNotifications() {
        XCTAssertNil(IncomingCallDetector.detect(texts: ["Message"], buttons: ["Répondre"]))
        XCTAssertNil(IncomingCallDetector.detect(texts: ["Invitation"], buttons: ["Accepter"]))
        XCTAssertNil(IncomingCallDetector.detect(texts: [], buttons: []))
    }

    func testCallBannerWithoutTextStillShows() {
        XCTAssertEqual(IncomingCallDetector.detect(texts: [], buttons: ["Accepter", "Refuser"])?.caller, "Appel entrant")
    }
}
