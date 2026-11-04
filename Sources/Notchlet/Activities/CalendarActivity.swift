import SwiftUI

/// Activité brève : un événement commence bientôt.
struct CalendarReminderActivity: Activity {
    let event: CalendarEvent
    var duration: TimeInterval = 5

    var id: String { "calendar.\(event.id)" }
    var displayDuration: TimeInterval { duration }
    var closedWing: CGFloat { 60 }

    var closedView: AnyView {
        AnyView(
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(cgColor: event.color))
                Spacer()
                Text(event.countdown(from: Date()))
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        )
    }

    var closedFooter: AnyView? {
        AnyView(
            Text(event.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 16)
        )
    }
}

/// Activité de fond : le prochain événement, de chaque côté de l'encoche.
struct CalendarIdleActivity: Activity {
    let calendar: CalendarManager

    let id = "calendar"
    var closedWing: CGFloat { 60 }
    var closedView: AnyView { AnyView(CalendarIdleView(calendar: calendar)) }
}

private struct CalendarIdleView: View {
    @ObservedObject var calendar: CalendarManager

    var body: some View {
        // Le temps restant se met à jour chaque minute, sans autre minuteur.
        TimelineView(.everyMinute) { context in
            if let event = calendar.nextTimedEvent(after: context.date) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(cgColor: event.color))
                    Spacer()
                    Text(event.countdown(from: context.date))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
            }
        }
    }
}
