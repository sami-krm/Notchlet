import AppKit
import CoreImage

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var bundleID: String
}

/// Dernière position connue. Entre deux lectures, on la calcule à partir de l'heure :
/// inutile d'interroger le lecteur chaque seconde.
struct PlaybackProgress: Equatable {
    var position: TimeInterval
    var duration: TimeInterval
    var updatedAt: Date

    func position(at date: Date, isPlaying: Bool) -> TimeInterval {
        let elapsed = isPlaying ? date.timeIntervalSince(updatedAt) : 0
        return min(max(position + elapsed, 0), duration)
    }

    /// Position demandée par l'utilisateur, ramenée dans les limites du morceau.
    func seeking(to newPosition: TimeInterval, at date: Date) -> PlaybackProgress {
        PlaybackProgress(position: min(max(newPosition, 0), duration), duration: duration, updatedAt: date)
    }
}

/// Suit la lecture dans Spotify et Musique.
///
/// État : via les notifications "distribuées" que ces apps publient à chaque
/// changement de morceau / play / pause.
/// Pochette, position et commandes : via AppleScript → macOS demandera une autorisation
/// "Automatisation" dès le premier morceau détecté.
@MainActor
final class MediaManager: NSObject, ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: PlaybackProgress?
    @Published private(set) var artwork: NSImage?
    /// Couleur dominante de la pochette, assez vive pour rester lisible sur fond noir.
    @Published private(set) var accentColor: NSColor?

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

    private func handle(_ info: [AnyHashable: Any]?, bundleID: String) {
        let trackChanged = applyState(info, bundleID: bundleID)
        guard track != nil else { return }
        if trackChanged { loadArtwork() }
        refreshProgress()
    }

    /// Met à jour l'état à partir d'une notification, sans appeler AppleScript.
    /// Renvoie `true` si le morceau a changé.
    @discardableResult
    func applyState(_ info: [AnyHashable: Any]?, bundleID: String) -> Bool {
        guard let info else { return false }
        let state = info["Player State"] as? String ?? "Stopped"

        if state == "Stopped" {
            if track?.bundleID == bundleID {
                track = nil
                isPlaying = false
                progress = nil
                artwork = nil
                accentColor = nil
            }
            return false
        }

        let new = Track(
            title: info["Name"] as? String ?? track?.title ?? "Titre inconnu",
            artist: info["Artist"] as? String ?? track?.artist ?? "",
            album: info["Album"] as? String ?? "",
            bundleID: bundleID
        )
        let trackChanged = new != track
        if trackChanged {
            track = new
            progress = nil
        }

        let nowPlaying = (state == "Playing")
        if nowPlaying != isPlaying, let current = progress {
            // Lecture ou pause : on fige la position atteinte avant de changer d'état.
            let now = Date()
            progress = PlaybackProgress(position: current.position(at: now, isPlaying: isPlaying),
                                        duration: current.duration, updatedAt: now)
        }
        isPlaying = nowPlaying
        return trackChanged
    }

    // MARK: - Contrôles

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let appName = runningPlayerName else { return }
        Task { _ = await Self.runAppleScript("tell application \"\(appName)\" to \(command)") }
    }

    /// Nom AppleScript du lecteur. `nil` s'il est fermé : un `tell` le relancerait.
    private var runningPlayerName: String? {
        guard let id = track?.bundleID,
              !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty
        else { return nil }
        return Self.players[id]
    }

    // MARK: - Position

    /// Avance ou recule dans le morceau. La barre bouge tout de suite, puis on relit
    /// la position réelle une fois la commande exécutée.
    func seek(to position: TimeInterval) {
        guard let appName = runningPlayerName, let target = progress?.seeking(to: position, at: Date()) else { return }
        progress = target
        // `Double` s'écrit toujours avec un point, la seule forme qu'accepte le code AppleScript.
        let script = "tell application \"\(appName)\" to set player position to \(target.position)"
        Task {
            _ = await Self.runAppleScript(script)
            refreshProgress()
        }
    }

    /// Relit la position réelle : au changement d'état et à l'ouverture de l'île,
    /// car une avance manuelle dans le morceau n'envoie pas toujours de notification.
    func refreshProgress() {
        guard let appName = runningPlayerName, let requested = track else { return }
        let isSpotify = requested.bundleID == "com.spotify.client"
        let script = """
        tell application "\(appName)" to return (player position as text) & "|" & (duration of current track as text)
        """
        Task {
            guard let output = await Self.runAppleScript(script),
                  track == requested,
                  let values = Self.parseProgress(output, isSpotify: isSpotify)
            else { return }
            progress = PlaybackProgress(position: values.position, duration: values.duration, updatedAt: Date())
        }
    }

    /// Lit "position|durée". Selon la langue du Mac, AppleScript écrit "12,5" ou "12.5".
    nonisolated static func parseProgress(_ output: String, isSpotify: Bool) -> (position: TimeInterval, duration: TimeInterval)? {
        let parts = output.split(separator: "|").map { $0.replacingOccurrences(of: ",", with: ".") }
        guard parts.count == 2, let position = TimeInterval(parts[0]), var duration = TimeInterval(parts[1]),
              duration > 0
        else { return nil }
        // shortcut: Spotify documente des secondes mais peut renvoyer des millisecondes ;
        // au-delà de 10 000 on suppose des ms. Une piste Spotify de plus de 2 h 45 serait fausse.
        if isSpotify, duration > 10_000 { duration /= 1000 }
        return (position, duration)
    }

    // MARK: - Pochette

    private func loadArtwork() {
        guard let appName = runningPlayerName, let requested = track else { return }
        let isSpotify = requested.bundleID == "com.spotify.client"
        let property = isSpotify ? "artwork url" : "raw data of artwork 1"
        Task {
            var data: Data?
            if let output = await Self.runAppleScript("tell application \"\(appName)\" to return \(property) of current track") {
                data = isSpotify ? await Self.download(from: output) : Self.parseArtworkData(output)
            }
            // Le morceau a pu changer pendant l'attente : on ignore cette réponse périmée.
            guard track == requested else { return }
            await showArtwork(data)
        }
    }

    /// Affiche la pochette. Le calcul de sa couleur, plus coûteux, se fait hors du thread principal.
    func showArtwork(_ data: Data?) async {
        guard let data else {
            artwork = nil
            accentColor = nil
            return
        }
        let color = await Task.detached(priority: .userInitiated) {
            Self.accentColor(of: data)
        }.value
        artwork = NSImage(data: data)
        accentColor = color
    }

    private nonisolated static func download(from address: String) async -> Data? {
        guard let url = URL(string: address), url.scheme == "https",
              let (data, _) = try? await URLSession.shared.data(from: url)
        else { return nil }
        return data
    }

    /// AppleScript affiche une image sous la forme «data JPEGFFD8…» : un code de 4 lettres,
    /// puis les octets en hexadécimal.
    nonisolated static func parseArtworkData(_ output: String) -> Data? {
        guard output.hasPrefix("«data "), output.hasSuffix("»") else { return nil }
        let hex = Array(output.dropFirst("«data ".count + 4).dropLast().utf8)
        guard !hex.isEmpty, hex.count.isMultiple(of: 2) else { return nil }

        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        for i in stride(from: 0, to: hex.count, by: 2) {
            guard let high = hexValue(hex[i]), let low = hexValue(hex[i + 1]) else { return nil }
            bytes.append(high << 4 | low)
        }
        return Data(bytes)
    }

    private nonisolated static func hexValue(_ character: UInt8) -> UInt8? {
        switch character {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return character - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return character - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return character - UInt8(ascii: "a") + 10
        default: return nil
        }
    }

    /// Moyenne des pixels (`CIAreaAverage`), ravivée pour ne pas donner un gris terne.
    nonisolated static func accentColor(of data: Data) -> NSColor? {
        guard let image = CIImage(data: data),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: image,
                  kCIInputExtentKey: CIVector(cgRect: image.extent),
              ]),
              let output = filter.outputImage
        else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: nil
        )

        let average = NSColor(srgbRed: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                              blue: CGFloat(pixel[2]) / 255, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return NSColor(hue: hue, saturation: min(saturation * 1.4, 1), brightness: max(brightness, 0.7), alpha: 1)
    }

    // MARK: - AppleScript

    /// Lance `osascript` sur un thread secondaire. Un lecteur bloqué peut faire attendre
    /// AppleScript deux minutes : sur le thread principal, l'interface serait figée.
    private nonisolated static func runAppleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                // Lire avant d'attendre la fin : une pochette peut remplir le tuyau et tout bloquer.
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: process.terminationStatus == 0 ? text : nil)
            }
        }
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
