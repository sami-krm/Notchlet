import AppKit
import EventKit

/// Un événement, copié depuis EventKit : les vues n'ont pas à connaître `EKEvent`.
struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: CGColor
    let joinLink: URL?

    /// Temps restant affiché dans l'île : quelques minutes, sinon l'heure de début.
    func countdown(from now: Date) -> String {
        if start <= now { return "En cours" }
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "\(minutes) min" : start.formatted(date: .omitted, time: .shortened)
    }
}

struct CalendarInfo: Identifiable {
    let id: String
    let title: String
    let color: CGColor
}

/// Cherche un lien de visioconférence dans les textes d'un événement.
enum MeetingLink {
    /// Ces textes peuvent venir d'une invitation envoyée par n'importe qui : seuls des liens
    /// HTTPS vers ces services sont retenus, et le nom de domaine doit correspondre exactement.
    private static let hosts = ["meet.google.com", "teams.microsoft.com", "teams.live.com", "zoom.us", "webex.com"]

    static func isMeeting(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        for case let text? in texts {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                if let url = match.url, isMeeting(url) { return url }
            }
        }
        return nil
    }
}

/// Décide quels rappels déclencher et quand se réveiller.
enum ReminderPlanner {
    static func due(in events: [CalendarEvent], now: Date, lead: TimeInterval, alerted: Set<String>) -> [CalendarEvent] {
        events.filter { event in
            !event.isAllDay && !alerted.contains(event.id)
                && event.start.addingTimeInterval(-lead) <= now && now < event.start
        }
    }

    /// Prochain instant où quelque chose change : un rappel, un début ou une fin d'événement.
    static func nextWake(for events: [CalendarEvent], now: Date, lead: TimeInterval) -> Date? {
        events
            .flatMap { [$0.start.addingTimeInterval(-lead), $0.start, $0.end] }
            .filter { $0 > now }
            .min()
    }
}

/// Événements à venir et rappels, via EventKit.
///
/// Permission : Calendrier, demandée quand on active la rubrique. EventKit donne accès à tous
/// les calendriers configurés dans l'app Calendrier du Mac.
@MainActor
final class CalendarManager: NSObject, ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var isDenied = false
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var calendars: [CalendarInfo] = []

    var onReminder: (@MainActor (CalendarEvent) -> Void)?

    private let store = EKEventStore()
    private var alerted: Set<String> = []
    private var wakeTimer: Timer?

    func start() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(refresh), name: .EKEventStoreChanged, object: store)
        center.addObserver(self, selector: #selector(refresh), name: UserDefaults.didChangeNotification, object: nil)
        // Un minuteur prend du retard pendant la veille : on recalcule tout au réveil.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil
        )
        refresh()
    }

    func requestAccess() {
        Task {
            if #available(macOS 14.0, *) {
                _ = try? await store.requestFullAccessToEvents()
            } else {
                _ = try? await store.requestAccess(to: .event)
            }
            refresh()
        }
    }

    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        else { return }
        NSWorkspace.shared.open(url)
    }

    func join(_ event: CalendarEvent) {
        // Revérifié ici : c'est le dernier point avant d'ouvrir une adresse venue d'une invitation.
        guard let link = event.joinLink, MeetingLink.isMeeting(link) else { return }
        NSWorkspace.shared.open(link)
    }

    func isVisible(_ calendar: CalendarInfo) -> Bool {
        !hiddenCalendarIDs.contains(calendar.id)
    }

    func setVisible(_ visible: Bool, calendar: CalendarInfo) {
        var hidden = hiddenCalendarIDs
        if visible { hidden.remove(calendar.id) } else { hidden.insert(calendar.id) }
        UserDefaults.standard.set(Array(hidden), forKey: SettingsKey.hiddenCalendarIDs)
    }

    private var hiddenCalendarIDs: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: SettingsKey.hiddenCalendarIDs) ?? [])
    }

    /// Prochain événement avec une heure précise, pour l'île fermée.
    func nextTimedEvent(after now: Date = Date()) -> CalendarEvent? {
        events.first { !$0.isAllDay && $0.end > now }
    }

    @objc private func refresh() {
        let status = EKEventStore.authorizationStatus(for: .event)
        var authorized = status == .authorized
        if #available(macOS 14.0, *), status == .fullAccess { authorized = true }
        if authorized != isAuthorized { isAuthorized = authorized }
        let denied = status == .denied || status == .restricted
        if denied != isDenied { isDenied = denied }

        wakeTimer?.invalidate()
        guard authorized, UserDefaults.standard.bool(forKey: SettingsKey.calendarEnabled) else {
            if !events.isEmpty { events = [] }
            return
        }

        let available = store.calendars(for: .event)
        calendars = available.map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: $0.cgColor) }

        let hidden = hiddenCalendarIDs
        let shown = available.filter { !hidden.contains($0.calendarIdentifier) }
        let now = Date()
        let fetched = fetchEvents(from: now, calendars: shown)
        if fetched != events { events = fetched }

        let defaults = UserDefaults.standard
        let lead = defaults.double(forKey: SettingsKey.calendarReminderLead) * 60
        if defaults.bool(forKey: SettingsKey.calendarReminderEnabled) {
            for event in ReminderPlanner.due(in: fetched, now: now, lead: lead, alerted: alerted) {
                alerted.insert(event.id)
                if defaults.bool(forKey: SettingsKey.calendarSoundEnabled) {
                    NSSound(named: "Glass")?.play()
                }
                onReminder?(event)
            }
        }

        // Sans événement proche, on relit quand même toutes les heures pour voir venir les suivants.
        let fallback = now.addingTimeInterval(3600)
        let wake = min(ReminderPlanner.nextWake(for: fetched, now: now, lead: lead) ?? fallback, fallback)
        let timer = Timer(fireAt: wake, interval: 0, target: self, selector: #selector(refresh), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        wakeTimer = timer
    }

    private func fetchEvents(from now: Date, calendars: [EKCalendar]) -> [CalendarEvent] {
        // Une liste vide voudrait dire « tous les calendriers » pour EventKit.
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(
            withStart: now, end: now.addingTimeInterval(48 * 3600), calendars: calendars
        )
        return store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { $0.compareStartDate(with: $1) == .orderedAscending }
            .map { event in
                CalendarEvent(
                    // Toutes les occurrences d'un événement répété partagent le même identifiant.
                    id: "\(event.eventIdentifier ?? event.title ?? "")|\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "Sans titre",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: event.calendar.cgColor,
                    joinLink: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
                )
            }
    }
}
