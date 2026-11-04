import SwiftUI

// `NSObject` est nécessaire pour que le timer appelle une méthode par `#selector`.
@MainActor
final class NotchViewModel: NSObject, ObservableObject {
    enum State { case closed, open }

    @Published var state: State = .closed
    @Published var geometry: NotchGeometry
    /// Activités brèves en attente : la première est affichée, puis retirée à la fin de sa durée.
    @Published private(set) var transientQueue: [any Activity] = []
    /// Ligne de volume sous les commandes de lecture.
    @Published var showsVolumeControl = false
    /// Avec de la musique, affiche les événements à la place du lecteur.
    @Published var showsCalendar = false

    let calendar = CalendarManager()
    let chime = ChimeManager()
    let media = MediaManager()
    let battery = BatteryManager()
    let hud = HUDManager()
    let bluetooth = BluetoothManager()

    // Rayons de la forme (fermée / ouverte)
    let closedTopRadius: CGFloat = 6
    let closedBottomRadius: CGFloat = 10
    let openTopRadius: CGFloat = 9
    let openBottomRadius: CGFloat = 26

    var openSize: CGSize {
        // 345 points visibles : la forme retire `openTopRadius` de chaque côté.
        CGSize(width: 345 + 2 * openTopRadius, height: showsVolumeControl ? 205 : 174)
    }

    /// Hauteur ajoutée sous l'encoche quand l'activité affichée a une ligne en plus.
    let closedFooterHeight: CGFloat = 22

    private var transientTimer: Timer?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var topRadius: CGFloat { state == .open ? openTopRadius : closedTopRadius }
    var bottomRadius: CGFloat { state == .open ? openBottomRadius : closedBottomRadius }

    var closedSize: CGSize {
        var width = geometry.notchSize.width + 2 * closedTopRadius
        if let displayed { width += 2 * displayed.closedWing }
        let footer = displayed?.closedFooter == nil ? 0 : closedFooterHeight
        return CGSize(width: width, height: geometry.notchSize.height + footer)
    }

    var currentSize: CGSize { state == .open ? openSize : closedSize }

    // MARK: - Activités

    /// Une activité brève passe avant l'activité de fond, puis celle-ci revient.
    var displayed: (any Activity)? { transientQueue.first ?? background }

    private var background: (any Activity)? {
        let idle = UserDefaults.standard.string(forKey: SettingsKey.idleActivity)
        if idle == IdleActivity.none.rawValue { return nil }
        if idle == IdleActivity.calendar.rawValue, calendar.nextTimedEvent() != nil {
            return CalendarIdleActivity(calendar: calendar)
        }
        return media.track == nil ? nil : MusicActivity(media: media)
    }

    /// Sans musique, les événements s'affichent d'office ; avec musique, à la demande.
    var showsCalendarPage: Bool {
        !calendar.events.isEmpty && (media.track == nil || showsCalendar)
    }

    func startCalendar() {
        calendar.onReminder = { [weak self] event in
            self?.enqueue(CalendarReminderActivity(
                event: event,
                duration: UserDefaults.standard.double(forKey: SettingsKey.calendarAlertDuration)
            ))
        }
        calendar.start()
        chime.start()
    }

    /// Branche les alertes de batterie sur la file. Séparé de `init` pour que les tests
    /// ne déclenchent ni alerte ni son selon l'état réel de la batterie.
    func startBatteryAlerts() {
        battery.onAlert = { [weak self] alert in
            let defaults = UserDefaults.standard
            self?.enqueue(BatteryAlertActivity(
                alert: alert,
                duration: defaults.double(forKey: SettingsKey.batteryAlertDuration),
                showsPercentage: !defaults.bool(forKey: SettingsKey.batteryHidesPercentage)
            ))
        }
        battery.update()
    }

    func startHUD() {
        hud.onActivity = { [weak self] activity in
            self?.showImmediately(activity)
        }
        hud.start()
    }

    func startBluetooth() {
        bluetooth.onActivity = { [weak self] activity in
            self?.enqueue(activity)
        }
        bluetooth.start()
    }

    /// Affiche l'activité tout de suite, sans attendre la file : un HUD doit répondre à
    /// l'appui. Elle remplace une activité de même genre et relance la durée d'affichage.
    func showImmediately(_ activity: any Activity) {
        transientQueue.removeAll { $0.id == activity.id }
        transientQueue.insert(activity, at: 0)
        startTransientTimer()
    }

    func enqueue(_ activity: any Activity) {
        // Brancher et débrancher plusieurs fois ne doit pas empiler la même alerte.
        guard !transientQueue.contains(where: { $0.id == activity.id }) else { return }
        transientQueue.append(activity)
        if transientQueue.count == 1 { startTransientTimer() }
    }

    /// Retire l'activité brève affichée et passe à la suivante.
    @objc func finishCurrentTransient() {
        transientTimer?.invalidate()
        transientTimer = nil
        guard !transientQueue.isEmpty else { return }
        transientQueue.removeFirst()
        if !transientQueue.isEmpty { startTransientTimer() }
    }

    private func startTransientTimer() {
        transientTimer?.invalidate()
        guard let current = transientQueue.first else { return }
        let timer = Timer(timeInterval: current.displayDuration, target: self,
                          selector: #selector(finishCurrentTransient), userInfo: nil, repeats: false)
        // Mode `.common` : le timer continue de tourner pendant un survol ou un défilement.
        RunLoop.main.add(timer, forMode: .common)
        transientTimer = timer
    }
}
