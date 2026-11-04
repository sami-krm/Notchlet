import AppKit
import IOKit.ps

enum BatteryAlert: Equatable {
    case charging(level: Int)
    case low(level: Int)
}

/// Décide quand alerter, à partir des relevés successifs de la batterie.
struct BatteryAlertMonitor {
    private var wasPluggedIn: Bool?
    private var lowAlertShown = false

    mutating func update(level: Int, isPluggedIn: Bool, threshold: Int) -> BatteryAlert? {
        defer { wasPluggedIn = isPluggedIn }

        if isPluggedIn {
            lowAlertShown = false
            // Au tout premier relevé, `wasPluggedIn` vaut nil : lancer l'app n'est pas un branchement.
            return wasPluggedIn == false ? .charging(level: level) : nil
        }
        guard level <= threshold else {
            lowAlertShown = false
            return nil
        }
        guard !lowAlertShown else { return nil }
        lowAlertShown = true
        return .low(level: level)
    }
}

/// Lit la batterie via IOKit (rien à afficher sur un Mac de bureau).
@MainActor
final class BatteryManager: ObservableObject {
    @Published private(set) var level: Int?
    @Published private(set) var isCharging = false
    /// Distinct de `isCharging` : un Mac branché peut ne pas charger, par exemple à 100 %.
    @Published private(set) var isPluggedIn = false

    /// Appelé quand une alerte activée dans les réglages se déclenche.
    var onAlert: (@MainActor (BatteryAlert) -> Void)?

    private var alertMonitor = BatteryAlertMonitor()
    private var runLoopSource: CFRunLoopSource?

    init() {
        readPowerSource()

        // macOS appelle cette fonction à chaque changement d'alimentation : pas besoin
        // d'interroger la batterie à intervalle régulier. C'est une fonction C : elle ne peut
        // pas capturer `self`, qu'on lui transmet donc sous forme de pointeur.
        let context = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            // La source est ajoutée à la boucle du thread principal : on y est déjà.
            MainActor.assumeIsolated {
                Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue().update()
            }
        }, context)?.takeRetainedValue()
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    deinit {
        // Sinon macOS rappellerait la fonction C avec un pointeur vers un objet disparu.
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    /// Relit la batterie et déclenche l'alerte éventuelle.
    func update() {
        readPowerSource()
        guard let level else { return }

        let defaults = UserDefaults.standard
        let threshold = defaults.integer(forKey: SettingsKey.lowBatteryThreshold)
        // Le moniteur voit chaque relevé, même si l'alerte est désactivée, pour rester à jour.
        guard let alert = alertMonitor.update(level: level, isPluggedIn: isPluggedIn, threshold: threshold)
        else { return }

        switch alert {
        case .charging:
            guard defaults.bool(forKey: SettingsKey.chargeAlertEnabled) else { return }
        case .low:
            guard defaults.bool(forKey: SettingsKey.lowBatteryAlertEnabled) else { return }
            if defaults.bool(forKey: SettingsKey.lowBatterySoundEnabled) {
                NSSound(named: "Funk")?.play()
            }
        }
        onAlert?(alert)
    }

    private func readPowerSource() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            level = nil
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            level = max > 0 ? current * 100 / max : nil
            isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            isPluggedIn = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return
        }
        level = nil
    }
}
