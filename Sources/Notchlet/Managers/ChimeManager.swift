import AppKit

/// Carillon joué à chaque heure pile, avec un son fourni par macOS.
@MainActor
final class ChimeManager: NSObject {
    private var timer: Timer?

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(schedule), name: UserDefaults.didChangeNotification, object: nil
        )
        schedule()
    }

    static func nextHour(after date: Date) -> Date? {
        Calendar.current.nextDate(after: date, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
    }

    @objc private func schedule() {
        timer?.invalidate()
        timer = nil
        guard UserDefaults.standard.bool(forKey: SettingsKey.hourlyChimeEnabled),
              let next = Self.nextHour(after: Date())
        else { return }
        let timer = Timer(fireAt: next, interval: 0, target: self, selector: #selector(ring(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func ring(_ timer: Timer) {
        // Après une veille, le minuteur part en retard : un carillon à 14 h 37 n'aurait pas de sens.
        if abs(timer.fireDate.timeIntervalSinceNow) < 60 {
            NSSound(named: "Tink")?.play()
        }
        schedule()
    }
}
