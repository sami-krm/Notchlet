import SwiftUI

enum HUDBarStyle: String, CaseIterable, Identifiable {
    case white, accent, glow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .white: return "Blanc"
        case .accent: return "Couleur d'accent"
        case .glow: return "Lumineux"
        }
    }
}

enum HUDAnimationSpeed: String, CaseIterable, Identifiable {
    case instant, fast, smooth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instant: return "Instantanée"
        case .fast: return "Rapide"
        case .smooth: return "Douce"
        }
    }

    /// `nil` : SwiftUI applique le changement sans animation.
    var animation: Animation? {
        switch self {
        case .instant: return nil
        case .fast: return .easeOut(duration: 0.1)
        case .smooth: return .spring(response: 0.35, dampingFraction: 0.8)
        }
    }
}

/// Activité brève : le volume ou la luminosité vient de changer.
struct HUDActivity: Activity {
    enum Kind { case volume, brightness }

    let kind: Kind
    let level: Float
    var isMuted = false
    var deviceName: String?

    var id: String { kind == .volume ? "hud.volume" : "hud.brightness" }
    var displayDuration: TimeInterval { 1.5 }
    var closedWing: CGFloat { 64 }

    var closedView: AnyView {
        AnyView(
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, alignment: .leading)
                Spacer()
                HUDBar(level: isMuted ? 0 : level)
                    .frame(width: 44)
            }
        )
    }

    var closedFooter: AnyView? {
        deviceName.map { name in
            AnyView(
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            )
        }
    }

    var symbol: String {
        switch kind {
        case .volume:
            if isMuted || level == 0 { return "speaker.slash.fill" }
            if level < 1 / 3 { return "speaker.wave.1.fill" }
            return level < 2 / 3 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        case .brightness:
            return level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }

    /// Niveau après un appui : 16 crans, comme macOS, en se recalant sur le cran le plus proche.
    static func steppedLevel(_ level: Float, up: Bool) -> Float {
        let step = (level * 16).rounded() + (up ? 1 : -1)
        return min(max(step, 0), 16) / 16
    }
}

private struct HUDBar: View {
    let level: Float
    @AppStorage(SettingsKey.hudBarStyle) private var style = HUDBarStyle.white
    @AppStorage(SettingsKey.hudAnimationSpeed) private var speed = HUDAnimationSpeed.fast

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(style == .accent ? Color.accentColor : Color.white)
                    .frame(width: proxy.size.width * CGFloat(level))
                    .shadow(color: style == .glow ? .white : .clear, radius: 4)
            }
        }
        .frame(height: 5)
        .animation(speed.animation, value: level)
    }
}
