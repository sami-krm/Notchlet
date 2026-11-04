import SwiftUI

/// Île ouverte : les prochains événements, avec un bouton pour rejoindre les visioconférences.
struct CalendarOpenView: View {
    let events: [CalendarEvent]
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let onJoin: (CalendarEvent) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(events.prefix(3)) { event in
                HStack(spacing: 9) {
                    Capsule()
                        .fill(Color(cgColor: event.color))
                        .frame(width: 4, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(Self.timeLabel(for: event, now: Date()))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if event.joinLink != nil {
                        Button("Rejoindre") { onJoin(event) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(NotchletStyle.accent))
                    }
                }
                .frame(height: 36)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
    }

    static func timeLabel(for event: CalendarEvent, now: Date) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(event.start) || event.start <= now {
            day = ""
        } else if calendar.isDateInTomorrow(event.start) {
            day = "Demain"
        } else {
            day = event.start.formatted(.dateTime.weekday(.wide))
        }
        if event.isAllDay {
            return day.isEmpty ? "Toute la journée" : "\(day), toute la journée"
        }
        let time = event.start.formatted(date: .omitted, time: .shortened)
        return day.isEmpty ? time : "\(day), \(time)"
    }
}
