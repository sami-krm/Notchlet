import SwiftUI

/// Activité de fond : le morceau en cours, de chaque côté de l'encoche.
struct MusicActivity: Activity {
    let media: MediaManager

    let id = "music"
    var closedView: AnyView { AnyView(MusicClosedView(media: media)) }
}

private struct MusicClosedView: View {
    @ObservedObject var media: MediaManager
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork

    var body: some View {
        if media.track != nil {
            HStack {
                ArtworkImage(media: media, size: 20, cornerRadius: 4)
                Spacer()
                EqualizerBars(isPlaying: media.isPlaying, color: style.accent(from: media.accentColor))
            }
        }
    }
}

/// Petites barres animées façon égaliseur.
struct EqualizerBars: View {
    var isPlaying: Bool
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(color)
                        .frame(width: 3,
                               height: isPlaying ? CGFloat(4 + 10 * abs(sin(t * 6 + Double(i) * 1.3))) : 3)
                }
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.12), value: t)
        }
    }
}

/// Barre de progression : un clic ou un glissement change la position. La vue ne se
/// redessine qu'une fois par seconde, et seulement quand l'île est ouverte.
struct TrackProgressBar: View {
    let progress: PlaybackProgress
    let isPlaying: Bool
    let color: Color
    let onSeek: (TimeInterval) -> Void

    /// Position sous le doigt pendant un glissement. La commande ne part qu'au relâchement,
    /// pour ne pas envoyer une commande au lecteur à chaque mouvement.
    @State private var draggedPosition: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = draggedPosition ?? progress.position(at: context.date, isPlaying: isPlaying)
            HStack(spacing: 8) {
                time(position)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.2))
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * position / progress.duration)
                    }
                    .frame(height: draggedPosition == nil ? 4 : 6)
                    .frame(maxHeight: .infinity)
                    // Toute la hauteur réagit au clic : 4 points seraient difficiles à viser.
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { draggedPosition = seekPosition(at: $0.location.x, width: proxy.size.width) }
                            .onEnded {
                                onSeek(seekPosition(at: $0.location.x, width: proxy.size.width))
                                draggedPosition = nil
                            }
                    )
                }
                .frame(height: 14)
                // Le temps restant, comme dans la plupart des lecteurs.
                time(progress.duration - position, prefix: "-")
            }
        }
    }

    private func seekPosition(at x: CGFloat, width: CGFloat) -> TimeInterval {
        progress.duration * min(max(x / width, 0), 1)
    }

    private func time(_ seconds: TimeInterval, prefix: String = "") -> some View {
        Text(prefix + Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
    }
}
