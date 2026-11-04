import AppKit
import ApplicationServices

/// Touche média du clavier, décodée depuis un événement système.
struct MediaKey: Equatable {
    enum Kind { case volumeUp, volumeDown, mute, brightnessUp, brightnessDown }

    let kind: Kind
    let isDown: Bool

    /// Les touches média ont le sous-type 8. `data1` contient le code de la touche dans ses
    /// 16 bits hauts, puis son état : 0x0A pour l'appui, 0x0B pour le relâchement.
    /// Codes : `NX_KEYTYPE_*` dans IOKit/hidsystem/ev_keymap.h.
    init?(subtype: Int, data1: Int) {
        guard subtype == 8 else { return nil }
        let state = (data1 & 0xFF00) >> 8
        guard state == 0x0A || state == 0x0B else { return nil }
        isDown = state == 0x0A

        switch (data1 & 0xFFFF_0000) >> 16 {
        case 0: kind = .volumeUp
        case 1: kind = .volumeDown
        case 2: kind = .brightnessUp
        case 3: kind = .brightnessDown
        case 7: kind = .mute
        default: return nil
        }
    }
}

/// Remplace les HUD de macOS : intercepte les touches de volume et de luminosité,
/// applique le changement, puis demande à l'île de l'afficher.
///
/// Permission : Accessibilité, indispensable pour bloquer une touche avant macOS.
@MainActor
final class HUDManager: NSObject, ObservableObject {
    /// macOS garde son droit de regard : l'Accessibilité peut être retirée à tout moment.
    @Published private(set) var isTrusted = AXIsProcessTrusted()

    var onActivity: (@MainActor (HUDActivity) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil
        )
        applySettings()
    }

    /// Fait apparaître la demande de macOS, qui renvoie vers Réglages Système.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
    }

    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Démarre ou arrête l'interception selon le réglage et la permission. Appelée aussi
    /// régulièrement : macOS ne prévient pas quand la permission change.
    @objc private func applySettings() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: SettingsKey.volumeHUDEnabled)
            || defaults.bool(forKey: SettingsKey.brightnessHUDEnabled)
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }

        if enabled && trusted {
            startEventTap()
        } else {
            stopEventTap()
        }

        if enabled, permissionTimer == nil {
            let timer = Timer(timeInterval: 2, target: self, selector: #selector(applySettings),
                              userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            permissionTimer = timer
        } else if !enabled {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    // MARK: - Interception des touches

    private func startEventTap() {
        guard eventTap == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        // Un `CGEventTap` voit les événements avant les apps et peut les bloquer. Type 14 :
        // `NX_SYSDEFINED`, celui des touches média.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // La source est ajoutée à la boucle du thread principal : on y est déjà.
                return MainActor.assumeIsolated {
                    Unmanaged<HUDManager>.fromOpaque(context).takeUnretainedValue().handle(type: type, event: event)
                }
            },
            userInfo: context
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        eventTap = tap
        runLoopSource = source
    }

    private func stopEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        self.eventTap = nil
        runLoopSource = nil
    }

    /// Renvoie l'événement pour le laisser passer vers macOS, ou `nil` pour le bloquer.
    /// Cette fonction doit rester rapide : macOS désactive un tap trop lent, et tout le
    /// clavier attend sa réponse.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        // shortcut: avec un modificateur (Option pour les réglages Son, Maj+Option pour le pas
        // fin), macOS garde la main et affiche son HUD ; à reprendre si le pas fin manque.
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        guard type.rawValue == 14, event.flags.intersection(modifiers).isEmpty,
              let nsEvent = NSEvent(cgEvent: event),
              let key = MediaKey(subtype: Int(nsEvent.subtype.rawValue), data1: nsEvent.data1),
              canHandle(key.kind)
        else { return Unmanaged.passUnretained(event) }

        if key.isDown {
            Task { @MainActor in self.perform(key.kind) }
        }
        return nil
    }

    private func canHandle(_ kind: MediaKey.Kind) -> Bool {
        let defaults = UserDefaults.standard
        switch kind {
        case .volumeUp, .volumeDown:
            return defaults.bool(forKey: SettingsKey.volumeHUDEnabled) && AudioOutput.canChangeVolume
        case .mute:
            return defaults.bool(forKey: SettingsKey.volumeHUDEnabled) && AudioOutput.canMute
        case .brightnessUp, .brightnessDown:
            return defaults.bool(forKey: SettingsKey.brightnessHUDEnabled) && DisplayBrightness.level != nil
        }
    }

    private func perform(_ kind: MediaKey.Kind) {
        switch kind {
        case .volumeUp, .volumeDown:
            guard let volume = AudioOutput.volume else { return }
            let new = HUDActivity.steppedLevel(volume, up: kind == .volumeUp)
            AudioOutput.setVolume(new)
            // Comme macOS : changer le volume coupe la sourdine.
            AudioOutput.setMuted(false)
            showVolume(level: new, isMuted: false)

        case .mute:
            let muted = !AudioOutput.isMuted
            AudioOutput.setMuted(muted)
            showVolume(level: AudioOutput.volume ?? 0, isMuted: muted)

        case .brightnessUp, .brightnessDown:
            guard let brightness = DisplayBrightness.level else { return }
            let new = HUDActivity.steppedLevel(brightness, up: kind == .brightnessUp)
            DisplayBrightness.setLevel(new)
            let defaults = UserDefaults.standard
            onActivity?(HUDActivity(kind: .brightness, level: new,
                                    duration: defaults.double(forKey: SettingsKey.brightnessHUDDuration),
                                    showsPercentage: defaults.bool(forKey: SettingsKey.brightnessShowsPercentage)))
        }
    }

    private func showVolume(level: Float, isMuted: Bool) {
        let defaults = UserDefaults.standard
        let showsDevice = defaults.bool(forKey: SettingsKey.hudShowsOutputDevice)
        onActivity?(HUDActivity(kind: .volume, level: level, isMuted: isMuted,
                                deviceName: showsDevice ? AudioOutput.deviceName : nil,
                                duration: defaults.double(forKey: SettingsKey.volumeHUDDuration),
                                showsPercentage: defaults.bool(forKey: SettingsKey.volumeShowsPercentage)))
    }
}
