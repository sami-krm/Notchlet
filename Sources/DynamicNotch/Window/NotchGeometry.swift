import AppKit

/// Taille de l'encoche physique (ou d'une encoche "virtuelle" sur les Mac sans encoche).
struct NotchGeometry: Equatable {
    var notchSize: CGSize
    var hasNotch: Bool

    static func from(_ screen: NSScreen) -> NotchGeometry {
        // Sur les MacBook à encoche, safeAreaInsets.top > 0 et les zones
        // auxiliaires gauche/droite encadrent l'encoche.
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NotchGeometry(
                notchSize: CGSize(width: width, height: screen.safeAreaInsets.top),
                hasNotch: true
            )
        }

        // Pas d'encoche : on simule une pilule de la hauteur de la barre des menus.
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchGeometry(
            notchSize: CGSize(width: 190, height: max(menuBarHeight, 24)),
            hasNotch: false
        )
    }

    /// Écran à utiliser : celui qui a une encoche, sinon l'écran principal.
    static func targetScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
