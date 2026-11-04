import AudioToolbox
import CoreAudio

/// Volume et nom de la sortie audio par défaut, via Core Audio (API publique, sans permission).
/// Pas d'état à publier ici : chaque valeur est relue à chaque appui, au cas où la sortie
/// aurait changé (AirPods branchés, par exemple).
enum AudioOutput {
    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static var device: AudioObjectID? {
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var property = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &property, 0, nil, &size, &id)
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    private static func isSettable(_ selector: AudioObjectPropertySelector) -> Bool {
        guard let device else { return false }
        var property = address(selector)
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &property, &settable) == noErr && settable.boolValue
    }

    /// Faux pour les sorties sans volume logiciel (certains écrans HDMI).
    static var canChangeVolume: Bool { isSettable(kAudioHardwareServiceDeviceProperty_VirtualMainVolume) }
    static var canMute: Bool { isSettable(kAudioDevicePropertyMute) }

    /// Volume de 0 à 1.
    static var volume: Float? {
        guard let device else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var property = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr ? value : nil
    }

    static func setVolume(_ value: Float) {
        guard let device else { return }
        var value = Float32(value)
        var property = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
    }

    static var isMuted: Bool {
        guard let device else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var property = address(kAudioDevicePropertyMute)
        return AudioObjectGetPropertyData(device, &property, 0, nil, &size, &value) == noErr && value != 0
    }

    static func setMuted(_ muted: Bool) {
        guard let device, canMute else { return }
        var value: UInt32 = muted ? 1 : 0
        var property = address(kAudioDevicePropertyMute)
        AudioObjectSetPropertyData(device, &property, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }

    static var deviceName: String? {
        guard let device else { return nil }
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var property = address(kAudioObjectPropertyName, scope: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    /// Identifiant stable de la sortie, nécessaire pour capturer le son du système.
    static var deviceUID: String? {
        guard let device else { return nil }
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        var property = address(kAudioDevicePropertyDeviceUID, scope: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(device, &property, 0, nil, &size, &uid) == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }
}
