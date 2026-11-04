import SwiftUI

/// Île ouverte quand un morceau est en cours : pochette, titre, progression et commandes.
struct MusicOpenView: View {
    @ObservedObject var vm: NotchViewModel
    @ObservedObject var media: MediaManager
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork

    private var accent: Color { style.accent(from: media.accentColor) }

    var body: some View {
        VStack(spacing: 13) {
            // La pochette occupe le coin à côté de l'encoche ; le texte s'aligne en bas pour
            // commencer sous l'encoche.
            HStack(alignment: .bottom, spacing: 12) {
                ArtworkImage(media: media, size: 56, cornerRadius: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text(media.track?.title ?? "")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text(media.track?.artist ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.bottom, 4)
                Spacer(minLength: 8)
                EqualizerBars(isPlaying: media.isPlaying, color: accent)
                    .padding(.bottom, 8)
            }

            if let progress = media.progress {
                TrackProgressBar(progress: progress, isPlaying: media.isPlaying, color: accent,
                                 onSeek: { media.seek(to: $0) })
            }

            HStack {
                MusicSideControl(media: media)
                Spacer()
                ControlButton(symbol: "backward.fill", size: 18) { media.previous() }
                Spacer()
                ControlButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 24) { media.playPause() }
                Spacer()
                ControlButton(symbol: "forward.fill", size: 18) { media.next() }
                Spacer()
                ControlButton(symbol: AudioOutputSymbol.current, size: 15, isActive: vm.showsVolumeControl) {
                    vm.showsVolumeControl.toggle()
                }
            }

            if vm.showsVolumeControl {
                VolumeRow()
                    .transition(.opacity)
            }
        }
        // 18 points de marge visible, plus ce que la forme de l'île retire sur les côtés.
        .padding(.horizontal, 18 + vm.openTopRadius)
        .padding(.top, 18)
    }
}

/// Bouton configurable à gauche des commandes.
private struct MusicSideControl: View {
    @ObservedObject var media: MediaManager
    @AppStorage(SettingsKey.musicSideButton) private var button = MusicSideButton.shuffle
    @State private var didCopy = false

    var body: some View {
        switch button {
        case .shuffle:
            ControlButton(symbol: button.symbol, size: 15, isActive: media.isShuffling) { media.toggleShuffle() }
        case .repeatTrack:
            ControlButton(symbol: button.symbol, size: 15, isActive: media.isRepeating) { media.toggleRepeat() }
        case .copyLink:
            ControlButton(symbol: didCopy ? "checkmark" : button.symbol, size: 15) {
                media.copyTrackLink()
                didCopy = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    didCopy = false
                }
            }
        }
    }
}

/// Symbole de la sortie audio en cours.
@MainActor
enum AudioOutputSymbol {
    static var current: String { symbol(deviceName: AudioOutput.deviceName) }

    static func symbol(deviceName: String?) -> String {
        guard let name = deviceName?.lowercased() else { return "speaker.wave.2.fill" }
        if name.contains("macbook") { return "laptopcomputer" }
        return BluetoothActivity.symbol(name: name, minorType: "Speaker")
    }
}

/// Ligne de volume. Le réglage s'applique pendant le glissement, pour entendre le résultat.
private struct VolumeRow: View {
    @State private var volume = AudioOutput.volume ?? 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2)).frame(height: 5)
                    Capsule().fill(Color.white).frame(width: proxy.size.width * CGFloat(volume), height: 5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        volume = Float(min(max(value.location.x / proxy.size.width, 0), 1))
                        AudioOutput.setVolume(volume)
                        AudioOutput.setMuted(false)
                    }
                )
            }
            .frame(height: 14)
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 2)
    }
}
