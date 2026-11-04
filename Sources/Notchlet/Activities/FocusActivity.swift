import SwiftUI

/// Activité brève : un mode de concentration démarre ou s'arrête.
struct FocusActivity: Activity {
    /// `nil` : la concentration vient de s'arrêter.
    let mode: FocusMode?

    var id: String { "focus" }
    var closedWing: CGFloat { 44 }

    /// Le symbole vient d'un fichier système : on se rabat sur la lune s'il est inconnu.
    var symbol: String {
        guard let mode else { return "moon" }
        return NSImage(systemSymbolName: mode.symbol, accessibilityDescription: nil) == nil ? "moon.fill" : mode.symbol
    }

    var closedView: AnyView {
        AnyView(
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(mode == nil ? Color.white.opacity(0.6) : Color.indigo)
                Spacer()
            }
        )
    }

    var closedFooter: AnyView? {
        AnyView(
            Text(mode?.name ?? "Concentration désactivée")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .padding(.horizontal, 16)
        )
    }
}
