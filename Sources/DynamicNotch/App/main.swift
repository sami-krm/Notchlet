import AppKit

// Point d'entrée : app "accessoire" (pas d'icône dans le Dock, pas de menu).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
