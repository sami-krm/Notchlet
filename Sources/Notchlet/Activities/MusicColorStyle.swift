import SwiftUI

/// Apparence de la musique dans l'île. `String` permet de l'enregistrer avec `@AppStorage`.
enum MusicColorStyle: String, CaseIterable, Identifiable {
    case artwork, colored, gradient, monochrome

    var id: String { rawValue }

    var label: String {
        switch self {
        case .artwork: return "Pochette"
        case .colored: return "Coloré"
        case .gradient: return "Dégradé"
        case .monochrome: return "Monochrome"
        }
    }

    func accent(from color: NSColor?) -> Color {
        guard self != .monochrome else { return .white }
        return color.map(Color.init(nsColor:)) ?? .green
    }
}

/// Bouton placé à gauche des commandes de lecture.
enum MusicSideButton: String, CaseIterable, Identifiable {
    case shuffle, repeatTrack, copyLink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shuffle: return "Aléatoire"
        case .repeatTrack: return "Répétition"
        case .copyLink: return "Copier le lien"
        }
    }

    var symbol: String {
        switch self {
        case .shuffle: return "shuffle"
        case .repeatTrack: return "repeat"
        case .copyLink: return "link"
        }
    }
}

/// Pochette du morceau, ou icône de l'app quand elle n'est pas disponible.
struct ArtworkImage: View {
    @ObservedObject var media: MediaManager
    let size: CGFloat
    let cornerRadius: CGFloat
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork

    var body: some View {
        Group {
            if let artwork = media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .grayscale(style == .monochrome ? 1 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else if let id = media.track?.bundleID, let icon = media.icon(for: id) {
                Image(nsImage: icon).resizable()
            } else {
                Image(systemName: "music.note")
            }
        }
        .frame(width: size, height: size)
    }
}

/// Fond de l'île ouverte. Il reste noir en haut : autour de l'encoche physique,
/// une autre couleur ferait apparaître sa découpe.
struct MusicBackground: View {
    @ObservedObject var media: MediaManager
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork

    private var fadeFromBlack: LinearGradient {
        LinearGradient(colors: [.black, .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            Color.black
            if media.track != nil {
                switch style {
                case .artwork:
                    if let artwork = media.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 30)
                        fadeFromBlack
                    }
                case .gradient:
                    style.accent(from: media.accentColor).opacity(0.7)
                    fadeFromBlack
                case .colored, .monochrome:
                    EmptyView()
                }
            }
        }
    }
}
