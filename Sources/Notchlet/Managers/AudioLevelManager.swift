import CoreAudio
import Foundation

/// Calculs sur le niveau sonore, sans dépendance au matériel.
enum AudioLevel {
    /// Racine de la moyenne des carrés : l'énergie moyenne du signal.
    static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sum = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sum / Float(samples.count)).squareRoot()
    }

    /// Ramène le niveau entre 0 et 1 sur une échelle en décibels, proche de ce que l'oreille perçoit.
    static func normalized(rms: Float) -> Float {
        guard rms > 0 else { return 0 }
        let decibels = 20 * log10(rms)
        return min(max((decibels + 50) / 50, 0), 1)
    }

    /// Fait défiler les barres : la plus récente entre à droite.
    static func pushing(_ level: Float, into levels: [Float]) -> [Float] {
        Array(levels.dropFirst()) + [level]
    }
}

/// Niveau du son joué par le Mac, pour l'onde sonore.
///
/// Permission : Enregistrement audio du système, demandée au premier lancement de la capture.
/// Le son n'est ni enregistré ni envoyé : seul son niveau est calculé, puis le son est jeté.
/// La capture ne tourne que pendant la lecture : macOS affiche alors un indicateur dans la
/// barre des menus.
@MainActor
final class AudioLevelManager: ObservableObject {
    static var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    @Published private(set) var levels = [Float](repeating: 0, count: 4)
    @Published private(set) var isCapturing = false

    private var isPlaying = false
    private var tap: AnyObject?

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applyState), name: UserDefaults.didChangeNotification, object: nil
        )
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        applyState()
    }

    @objc private func applyState() {
        let wanted = isPlaying && UserDefaults.standard.bool(forKey: SettingsKey.liveWaveformEnabled)
        guard #available(macOS 14.2, *), wanted != (tap != nil) else { return }
        if wanted {
            // shortcut: après un changement de sortie audio, l'onde peut rester plate jusqu'à la
            // prochaine pause ou reprise ; à suivre avec kAudioHardwarePropertyDefaultOutputDevice si gênant.
            tap = SystemAudioTap { [weak self] level in
                Task { @MainActor in self?.receive(level) }
            }
            isCapturing = tap != nil
        } else {
            tap = nil
            isCapturing = false
            levels = [Float](repeating: 0, count: levels.count)
        }
    }

    private func receive(_ level: Float) {
        guard tap != nil else { return }
        levels = AudioLevel.pushing(level, into: levels)
    }
}

/// Capture du son du système avec Core Audio, disponible depuis macOS 14.2. Un « tap » copie
/// le son en cours de lecture ; un appareil agrégé privé permet de lire cette copie.
@available(macOS 14.2, *)
private final class SystemAudioTap {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "com.samikrim.Notchlet.audio-level")

    init?(onLevel: @escaping @Sendable (Float) -> Void) {
        guard let outputUID = AudioOutput.deviceUID else { return nil }

        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Notchlet"
        description.isPrivate = true
        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr else { return nil }

        let device: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Notchlet",
            kAudioAggregateDeviceUIDKey: "com.samikrim.Notchlet.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: description.uuid.uuidString,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        guard AudioHardwareCreateAggregateDevice(device as CFDictionary, &deviceID) == noErr else {
            stop()
            return nil
        }

        // Le son arrive environ 100 fois par seconde : on regroupe pour redessiner 15 à 20 fois
        // par seconde, ce qui suffit à l'œil.
        var total: Float = 0
        var count = 0
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, deviceID, queue) { _, input, _, _, _ in
            let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let samples = UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self),
                                                  count: Int(buffer.mDataByteSize) / MemoryLayout<Float>.size)
                total += AudioLevel.rms(samples)
                count += 1
            }
            guard count >= 10 else { return }
            onLevel(AudioLevel.normalized(rms: total / Float(count)))
            total = 0
            count = 0
        }
        guard status == noErr, let procID, AudioDeviceStart(deviceID, procID) == noErr else {
            stop()
            return nil
        }
    }

    deinit {
        stop()
    }

    private func stop() {
        if let procID {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
            self.procID = nil
        }
        if deviceID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyAggregateDevice(deviceID)
            deviceID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != AudioObjectID(kAudioObjectUnknown) {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }
}
