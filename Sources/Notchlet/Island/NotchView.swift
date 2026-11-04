import SwiftUI

struct NotchView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media: MediaManager
    @ObservedObject var battery: BatteryManager
    @ObservedObject var calendar: CalendarManager

    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        let size = vm.currentSize
        let shape = NotchShape(topRadius: vm.topRadius, bottomRadius: vm.bottomRadius)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if vm.state == .open {
                    openContent
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else {
                    closedContent
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .background {
                // Fermée, l'île reste noire pour se confondre avec l'encoche.
                if vm.state == .open {
                    MusicBackground(media: media)
                } else {
                    Color.black
                }
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(vm.state == .open ? 0.45 : 0), radius: 14, y: 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .animation(spring, value: media.track)
        .animation(spring, value: vm.displayed?.id)
        .animation(spring, value: vm.geometry)
        .animation(spring, value: vm.showsVolumeControl)
        .animation(spring, value: vm.showsCalendarPage)
    }

    // MARK: - Fermée : "live activity" de chaque côté de l'encoche

    @ViewBuilder
    private var closedContent: some View {
        if let activity = vm.displayed {
            VStack(spacing: 0) {
                activity.closedView
                    .padding(.horizontal, vm.closedTopRadius + 10)
                    .frame(height: vm.geometry.notchSize.height)
                if let footer = activity.closedFooter {
                    footer.frame(height: vm.closedFooterHeight)
                }
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Ouverte

    private var openContent: some View {
        Group {
            if vm.showsCalendarPage {
                CalendarOpenView(
                    events: calendar.events,
                    horizontalPadding: 18 + vm.openTopRadius,
                    topPadding: vm.geometry.notchSize.height + 4,
                    onJoin: { calendar.join($0) }
                )
            } else if media.track == nil {
                idleOpenContent
            } else {
                MusicOpenView(vm: vm, media: media)
            }
        }
        // Avec de la musique et des événements : passer de l'un à l'autre, à droite de l'encoche.
        .overlay(alignment: .topTrailing) {
            if media.track != nil, !calendar.events.isEmpty {
                Button {
                    vm.showsCalendar.toggle()
                } label: {
                    Image(systemName: vm.showsCalendar ? "music.note" : "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(vm.showsCalendar ? "Afficher la musique" : "Afficher le calendrier")
                .padding(.top, 4)
                .padding(.trailing, vm.openTopRadius + 12)
            }
        }
        // Une activité brève s'affiche juste sous l'encoche : à côté, la place manque.
        .overlay(alignment: .topTrailing) {
            if let brief = vm.transientQueue.first {
                brief.closedView
                    .frame(width: 98, height: 28)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.85)))
                    .padding(.top, vm.geometry.notchSize.height + 2)
                    // La forme de l'île retire `openTopRadius` de chaque côté.
                    .padding(.trailing, vm.openTopRadius + 6)
            }
        }
    }

    /// Sans musique : l'heure, la date et la batterie, sous l'encoche.
    private var idleOpenContent: some View {
        VStack(spacing: 6) {
            Spacer(minLength: vm.geometry.notchSize.height)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    ClockView()
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    BatteryView(battery: battery)
                    Text("Lance Spotify ou Musique")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18 + vm.openTopRadius)
        .padding(.bottom, 14)
    }
}

// MARK: - Composants

struct ControlButton: View {
    let symbol: String
    var size: CGFloat = 14
    var isActive = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isActive ? NotchletStyle.accent : Color.white)
                .frame(width: 44, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(hovering || isActive ? 0.12 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ClockView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(context.date, format: .dateTime.hour().minute())
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}

struct BatteryView: View {
    @ObservedObject var battery: BatteryManager
    @AppStorage(SettingsKey.batteryHidesPercentage) private var hidesPercentage = false

    var body: some View {
        if let level = battery.level {
            HStack(spacing: 5) {
                if !hidesPercentage {
                    Text("\(level)%")
                        .font(.system(size: 12, weight: .medium))
                }
                Image(systemName: symbol(for: level))
                    .font(.system(size: 14))
                    .foregroundStyle(color(for: level))
            }
        }
    }

    private func symbol(for level: Int) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private func color(for level: Int) -> Color {
        if battery.isCharging { return .green }
        return level <= 20 ? .red : .white
    }
}
