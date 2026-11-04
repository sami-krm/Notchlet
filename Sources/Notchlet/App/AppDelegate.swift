import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: SettingsKey.defaults)

        let controller = NotchWindowController()
        controller.show()
        notchController = controller
        settingsWindow = SettingsWindowController(hud: controller.hud, bluetooth: controller.bluetooth,
                                                  calendar: controller.calendar, weather: controller.weather,
                                                  focus: controller.focus)

        setupStatusItem()

        // Écran branché/débranché, changement de résolution… → on repositionne l'île.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensChanged() {
        notchController?.reposition()
    }

    @objc private func openSettings() {
        settingsWindow?.show()
    }

    /// Petite icône dans la barre des menus : réglages et sortie de l'app.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Notchlet")

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter Notchlet",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }
}
