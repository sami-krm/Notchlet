import AppKit

/// Étagère : des raccourcis vers des fichiers, gardés le temps de la session.
/// Les fichiers restent à leur place : les retirer de l'étagère ne les supprime jamais.
@MainActor
final class ShelfManager: ObservableObject {
    @Published private(set) var files: [URL] = []

    func add(_ url: URL) {
        guard url.isFileURL, !files.contains(url) else { return }
        files.append(url)
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}
