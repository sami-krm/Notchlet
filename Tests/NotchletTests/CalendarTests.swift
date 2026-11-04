import CoreGraphics
import XCTest
@testable import Notchlet

@MainActor
final class CalendarTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 700_000_000)

    private func event(_ id: String = "a", startsIn minutes: Double, lasting: Double = 30, allDay: Bool = false) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(id: id, title: id, start: start, end: start.addingTimeInterval(lasting * 60),
                             isAllDay: allDay, color: CGColor(gray: 1, alpha: 1), joinLink: nil)
    }

    // MARK: - Liens de visioconférence

    func testFindsLinksForEachService() {
        for address in ["https://meet.google.com/abc-defg-hij",
                        "https://teams.microsoft.com/l/meetup-join/abc",
                        "https://teams.live.com/meet/123",
                        "https://us02web.zoom.us/j/123456",
                        "https://zoom.us/j/123456",
                        "https://acme.webex.com/meet/sami"] {
            XCTAssertEqual(MeetingLink.find(in: ["Lien : \(address) à bientôt"])?.absoluteString, address)
        }
    }

    func testRejectsLookalikeAndUnsafeLinks() {
        for address in ["https://meet.google.com.evil.com/abc",
                        "https://evil.com/meet.google.com",
                        "https://notzoom.us/j/1",
                        "http://meet.google.com/abc",
                        "https://exemple.com/reunion"] {
            XCTAssertNil(MeetingLink.find(in: [address]), address)
        }
    }

    func testSearchesEveryFieldAndIgnoresMissingOnes() {
        XCTAssertNotNil(MeetingLink.find(in: [nil, "Salle B", "Notes https://zoom.us/j/1"]))
        XCTAssertNil(MeetingLink.find(in: [nil, nil]))
    }

    // MARK: - Rappels

    func testReminderIsDueInsideLeadTimeOnly() {
        let lead: TimeInterval = 600
        XCTAssertEqual(ReminderPlanner.due(in: [event(startsIn: 5)], now: now, lead: lead, alerted: []).count, 1)
        XCTAssertEqual(ReminderPlanner.due(in: [event(startsIn: 20)], now: now, lead: lead, alerted: []).count, 0)
        XCTAssertEqual(ReminderPlanner.due(in: [event(startsIn: -5)], now: now, lead: lead, alerted: []).count, 0)
    }

    func testReminderFiresOnceAndSkipsAllDayEvents() {
        XCTAssertTrue(ReminderPlanner.due(in: [event(startsIn: 5)], now: now, lead: 600, alerted: ["a"]).isEmpty)
        XCTAssertTrue(ReminderPlanner.due(in: [event(startsIn: 5, allDay: true)], now: now, lead: 600, alerted: []).isEmpty)
    }

    func testNextWakeIsTheNearestFutureChange() {
        let upcoming = event(startsIn: 20)
        XCTAssertEqual(ReminderPlanner.nextWake(for: [upcoming], now: now, lead: 600), now.addingTimeInterval(600))
        // Déjà commencé : le prochain changement est sa fin.
        let ongoing = event(startsIn: -5, lasting: 30)
        XCTAssertEqual(ReminderPlanner.nextWake(for: [ongoing], now: now, lead: 600), now.addingTimeInterval(25 * 60))
        XCTAssertNil(ReminderPlanner.nextWake(for: [], now: now, lead: 600))
    }

    // MARK: - Affichage

    func testCountdownText() {
        XCTAssertEqual(event(startsIn: 10).countdown(from: now), "10 min")
        XCTAssertEqual(event(startsIn: 0.5).countdown(from: now), "1 min")
        XCTAssertEqual(event(startsIn: -1).countdown(from: now), "En cours")
        XCTAssertFalse(event(startsIn: 90).countdown(from: now).contains("min"))
    }

    func testIslandShowsCalendarPageOnlyWithEvents() {
        let vm = NotchViewModel(geometry: NotchGeometry(notchSize: CGSize(width: 180, height: 34), hasNotch: true))
        vm.showsCalendar = true
        XCTAssertFalse(vm.showsCalendarPage, "aucun événement : la liste serait vide")
    }

    func testChimeTargetsTheNextFullHour() throws {
        let next = try XCTUnwrap(ChimeManager.nextHour(after: now))
        let parts = Calendar.current.dateComponents([.minute, .second], from: next)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
        XCTAssertGreaterThan(next, now)
        XCTAssertLessThanOrEqual(next.timeIntervalSince(now), 3600)
    }
}
