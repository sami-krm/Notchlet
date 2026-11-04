import AppKit

// Point d'entrée : app "accessoire" (pas d'icône dans le Dock, pas de menu).
let app = NSApplication.shared
// Ce fichier s'exécute sur le thread principal, mais le compilateur ne peut pas le déduire.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
