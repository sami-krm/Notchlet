import AppKit
import SwiftUI

/// Fenêtre de réglages. La scène SwiftUI `Settings` demande une app déclarée avec `App` ;
/// la nôtre démarre par `main.swift`, on affiche donc la vue dans une `NSWindow`.
@MainActor
final class SettingsWindowController {
    private let hud: HUDManager
    private var window: NSWindow?

    init(hud: HUDManager) {
        self.hud = hud
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Une app "accessoire" n'est jamais active d'elle-même : sans cet appel,
        // la fenêtre resterait derrière les autres.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(hud: hud)))
        window.title = "Réglages de DynamicNotch"
        window.styleMask = [.titled, .closable]
        // La fenêtre fermée reste en mémoire pour être rouverte.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
