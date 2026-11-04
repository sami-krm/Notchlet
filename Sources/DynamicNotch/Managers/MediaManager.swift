import AppKit

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var bundleID: String
}

/// Suit la lecture dans Spotify et Musique.
///
/// Lecture : via les notifications "distribuées" que ces apps publient à chaque
/// changement de morceau / play / pause → aucune permission nécessaire.
/// Contrôle : via AppleScript → macOS demandera une autorisation "Automatisation"
/// la première fois.
@MainActor
final class MediaManager: NSObject, ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false

    private static let players: [String: String] = [
        "com.spotify.client": "Spotify",
        "com.apple.Music": "Music",
    ]

    private var iconCache: [String: NSImage] = [:]

    override init() {
        super.init()
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(spotifyChanged(_:)),
                           name: Notification.Name("com.spotify.client.PlaybackStateChanged"),
                           object: nil)
        center.addObserver(self, selector: #selector(musicChanged(_:)),
                           name: Notification.Name("com.apple.Music.playerInfo"),
                           object: nil)
    }

    @objc private func spotifyChanged(_ n: Notification) {
        handle(n.userInfo, bundleID: "com.spotify.client")
    }

    @objc private func musicChanged(_ n: Notification) {
        handle(n.userInfo, bundleID: "com.apple.Music")
    }

    func handle(_ info: [AnyHashable: Any]?, bundleID: String) {
        guard let info else { return }
        let state = info["Player State"] as? String ?? "Stopped"

        if state == "Stopped" {
            if track?.bundleID == bundleID {
                track = nil
                isPlaying = false
            }
            return
        }

        let new = Track(
            title: info["Name"] as? String ?? track?.title ?? "Titre inconnu",
            artist: info["Artist"] as? String ?? track?.artist ?? "",
            album: info["Album"] as? String ?? "",
            bundleID: bundleID
        )
        if new != track { track = new }
        isPlaying = (state == "Playing")
    }

    // MARK: - Contrôles

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let id = track?.bundleID,
              let appName = Self.players[id],
              !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
        else { return }

        var error: NSDictionary?
        NSAppleScript(source: "tell application \"\(appName)\" to \(command)")?
            .executeAndReturnError(&error)
        if let error { print("Erreur AppleScript :", error) }
    }

    // MARK: - Icône de l'app qui joue

    func icon(for bundleID: String) -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = icon
        return icon
    }
}
