import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchWindowController()
        controller.show()
        notchController = controller

        setupStatusItem()

        // Écran branché/débranché, changement de résolution… → on repositionne l'île.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @MainActor @objc private func screensChanged() {
        notchController?.reposition()
    }

    /// Petite icône dans la barre des menus, juste pour pouvoir quitter l'app.
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "DynamicNotch")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quitter DynamicNotch",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }
}
