import AppKit
import CoreAudio

/// Micro d'entrée par défaut, via Core Audio (API publique, sans permission : on demande
/// seulement si le micro est utilisé, sans jamais l'écouter).
enum AudioInput {
    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static var device: AudioObjectID? {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var property = address(kAudioHardwarePropertyDefaultInputDevice)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, &id)
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    static var isInUse: Bool {
        guard let device else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var property = address(kAudioDevicePropertyDeviceIsRunningSomewhere)
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr && value != 0
    }

    static var canMute: Bool {
        guard let device else { return false }
        var property = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &property, &settable) == noErr && settable.boolValue
    }

    static var isMuted: Bool {
        guard let device else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var property = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr && value != 0
    }

    static func setMuted(_ muted: Bool) {
        guard let device else { return }
        var value: UInt32 = muted ? 1 : 0
        var property = address(kAudioDevicePropertyMute, scope: kAudioObjectPropertyScopeInput)
        AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }
}

/// Évite de prendre une courte utilisation du micro pour un appel.
struct MicUseTracker {
    private var usedSince: Date?
    private let minimumDuration: TimeInterval = 4

    /// Renvoie le début de l'appel, ou `nil` s'il n'y en a pas.
    mutating func update(isInUse: Bool, now: Date) -> Date? {
        guard isInUse else {
            usedSince = nil
            return nil
        }
        let start = usedSince ?? now
        usedSince = start
        return now.timeIntervalSince(start) >= minimumDuration ? start : nil
    }
}

/// Appel en cours (micro utilisé) et appel entrant (bannière de notification).
@MainActor
final class CallManager: NSObject, ObservableObject {
    @Published private(set) var callStart: Date?
    @Published private(set) var incoming: IncomingCall?
    @Published private(set) var isMicMuted = false

    /// Appelé à l'arrivée d'un appel, pour ouvrir l'île.
    var onIncoming: (@MainActor () -> Void)?

    private var tracker = MicUseTracker()
    private let reader = IncomingCallReader()
    private var timer: Timer?

    var canMuteMic: Bool { AudioInput.canMute }

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil
        )
        applySettings()
    }

    @objc private func applySettings() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: SettingsKey.callIndicatorEnabled)
            || defaults.bool(forKey: SettingsKey.incomingCallsEnabled)
        guard enabled != (timer != nil) else { return }
        if enabled {
            let timer = Timer(timeInterval: 1, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else {
            timer?.invalidate()
            timer = nil
            callStart = nil
            incoming = nil
        }
    }

    @objc private func poll() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SettingsKey.callIndicatorEnabled) {
            let start = tracker.update(isInUse: AudioInput.isInUse, now: Date())
            if start != callStart { callStart = start }
            let muted = AudioInput.isMuted
            if muted != isMicMuted { isMicMuted = muted }
        } else if callStart != nil {
            callStart = nil
        }

        let call = defaults.bool(forKey: SettingsKey.incomingCallsEnabled) && AXIsProcessTrusted() ? reader.read() : nil
        if call != incoming {
            let isNew = incoming == nil && call != nil
            incoming = call
            if isNew { onIncoming?() }
        }
    }

    func toggleMicMute() {
        AudioInput.setMuted(!AudioInput.isMuted)
        isMicMuted = AudioInput.isMuted
    }

    func acceptIncoming() {
        reader.accept()
        incoming = nil
    }

    func declineIncoming() {
        reader.decline()
        incoming = nil
    }
}
