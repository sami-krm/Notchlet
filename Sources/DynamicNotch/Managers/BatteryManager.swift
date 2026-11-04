import Foundation
import IOKit.ps

/// Lit le niveau de batterie via IOKit (rien à afficher sur un Mac de bureau).
@MainActor
final class BatteryManager: NSObject, ObservableObject {
    @Published private(set) var level: Int?
    @Published private(set) var isCharging = false

    private var timer: Timer?

    override init() {
        super.init()
        update()
        let timer = Timer(timeInterval: 30, target: self, selector: #selector(update),
                          userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc func update() {
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
            return
        }
        level = nil
    }
}
