import SwiftUI

struct NotchView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media: MediaManager
    @ObservedObject var battery: BatteryManager

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
            .background(Color.black)
            .clipShape(shape)
            .shadow(color: .black.opacity(vm.state == .open ? 0.45 : 0), radius: 14, y: 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .animation(spring, value: media.track)
        .animation(spring, value: vm.displayed?.id)
        .animation(spring, value: vm.geometry)
    }

    // MARK: - Fermée : "live activity" de chaque côté de l'encoche

    @ViewBuilder
    private var closedContent: some View {
        if let activity = vm.displayed {
            activity.closedView
                .padding(.horizontal, vm.closedTopRadius + 10)
                .frame(height: vm.geometry.notchSize.height)
        } else {
            Color.clear
        }
    }

    // MARK: - Ouverte

    private var openContent: some View {
        VStack(spacing: 14) {
            // Ligne du haut : à gauche et à droite de l'encoche physique
            HStack {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                BatteryView(battery: battery)
            }
            .frame(height: vm.geometry.notchSize.height)

            HStack(spacing: 16) {
                MediaCard(media: media)
                Divider().overlay(Color.white.opacity(0.15))
                ClockView()
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, vm.openTopRadius + 20)
        .padding(.bottom, 18)
    }
}

// MARK: - Composants

struct MediaCard: View {
    @ObservedObject var media: MediaManager

    var body: some View {
        HStack(spacing: 12) {
            if let track = media.track {
                Group {
                    if let icon = media.icon(for: track.bundleID) {
                        Image(nsImage: icon).resizable()
                    } else {
                        Image(systemName: "music.note")
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    HStack(spacing: 18) {
                        ControlButton(symbol: "backward.fill") { media.previous() }
                        ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 18) { media.playPause() }
                        ControlButton(symbol: "forward.fill") { media.next() }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Lance Spotify ou Musique")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ControlButton: View {
    let symbol: String
    var size: CGFloat = 14
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(hovering ? 0.15 : 0)))
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
        .frame(width: 110)
    }
}

struct BatteryView: View {
    @ObservedObject var battery: BatteryManager

    var body: some View {
        if let level = battery.level {
            HStack(spacing: 5) {
                Text("\(level)%")
                    .font(.system(size: 12, weight: .medium))
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
