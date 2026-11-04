import SwiftUI

struct NotchView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media: MediaManager
    @ObservedObject var battery: BatteryManager
    @ObservedObject var calendar: CalendarManager
    @ObservedObject var weather: WeatherManager
    let shelf: ShelfManager
    @ObservedObject var calls: CallManager
    @AppStorage(SettingsKey.shelfEnabled) private var shelfEnabled = true

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
            if calls.incoming != nil || (calls.callStart != nil && !vm.showsShelf && !vm.showsCalendar) {
                CallOpenView(calls: calls, horizontalPadding: 18 + vm.openTopRadius,
                             topPadding: vm.geometry.notchSize.height + 6)
            } else if vm.showsShelf {
                ShelfOpenView(
                    shelf: shelf,
                    horizontalPadding: 18 + vm.openTopRadius,
                    topPadding: vm.geometry.notchSize.height + 6
                )
            } else if vm.showsCalendarPage {
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
        // Le calendrier et l'étagère prennent toute la place : la météo passe à gauche de l'encoche.
        .overlay(alignment: .topLeading) {
            if let report = weather.report, vm.showsShelf || vm.showsCalendarPage {
                WeatherBadge(report: report)
                    .frame(height: vm.geometry.notchSize.height)
                    .padding(.leading, vm.openTopRadius + 14)
            }
        }
        // Changer de page, à droite de l'encoche.
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                if media.track != nil, !calendar.events.isEmpty {
                    pageButton(symbol: vm.showsCalendar ? "music.note" : "calendar",
                               label: vm.showsCalendar ? "Afficher la musique" : "Afficher le calendrier") {
                        vm.showsCalendar.toggle()
                        vm.showsShelf = false
                    }
                }
                if shelfEnabled {
                    pageButton(symbol: "tray.full.fill",
                               label: vm.showsShelf ? "Fermer l'étagère" : "Afficher l'étagère",
                               isActive: vm.showsShelf) {
                        vm.showsShelf.toggle()
                    }
                }
            }
            .padding(.top, 4)
            .padding(.trailing, vm.openTopRadius + 8)
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

    private func pageButton(symbol: String, label: String, isActive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? NotchletStyle.accent : Color.white)
                .frame(width: 30, height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.1)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Sans musique : l'heure, la date, la batterie et la météo, sous l'encoche.
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
                    if let report = weather.report {
                        WeatherBadge(report: report)
                    } else {
                        Text("Lance Spotify ou Musique")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18 + vm.openTopRadius)
        .padding(.bottom, 14)
    }
}

// MARK: - Composants

struct WeatherBadge: View {
    let report: WeatherReport

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: report.symbol)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
            Text(report.temperatureText)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(report.label), \(report.temperatureText)")
    }
}

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
