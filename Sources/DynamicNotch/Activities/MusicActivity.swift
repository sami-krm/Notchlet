import SwiftUI

/// Activité de fond : le morceau en cours, de chaque côté de l'encoche.
struct MusicActivity: Activity {
    let media: MediaManager

    let id = "music"
    var closedView: AnyView { AnyView(MusicClosedView(media: media)) }
}

private struct MusicClosedView: View {
    @ObservedObject var media: MediaManager

    var body: some View {
        if let track = media.track {
            HStack {
                if let icon = media.icon(for: track.bundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Spacer()
                EqualizerBars(isPlaying: media.isPlaying)
            }
        }
    }
}

/// Petites barres animées façon égaliseur.
private struct EqualizerBars: View {
    var isPlaying: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(Color.green)
                        .frame(width: 3,
                               height: isPlaying ? CGFloat(4 + 10 * abs(sin(t * 6 + Double(i) * 1.3))) : 3)
                }
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.12), value: t)
        }
    }
}
