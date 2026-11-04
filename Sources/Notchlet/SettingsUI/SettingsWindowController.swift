import AppKit
import SwiftUI

/// Fenêtre de réglages. La scène SwiftUI `Settings` demande une app déclarée avec `App` ;
/// la nôtre démarre par `main.swift`, on affiche donc la vue dans une `NSWindow`.
@MainActor
final class SettingsWindowController {
    private let hud: HUDManager
    private let bluetooth: BluetoothManager
    private let calendar: CalendarManager
    private let weather: WeatherManager
    private let focus: FocusManager
    private var window: NSWindow?

    init(hud: HUDManager, bluetooth: BluetoothManager, calendar: CalendarManager, weather: WeatherManager,
         focus: FocusManager) {
        self.focus = focus
        self.hud = hud
        self.bluetooth = bluetooth
        self.calendar = calendar
        self.weather = weather
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
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(hud: hud, bluetooth: bluetooth, calendar: calendar, weather: weather, focus: focus)))
        window.title = "Réglages de Notchlet"
        // Le contenu monte sous la barre de titre, devenue invisible : seuls restent les
        // boutons de fenêtre, au-dessus de la barre latérale.
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        // La fenêtre fermée reste en mémoire pour être rouverte.
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
