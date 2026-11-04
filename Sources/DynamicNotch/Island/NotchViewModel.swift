import SwiftUI

// `NSObject` est nécessaire pour que le timer appelle une méthode par `#selector`.
@MainActor
final class NotchViewModel: NSObject, ObservableObject {
    enum State { case closed, open }

    @Published var state: State = .closed
    @Published var geometry: NotchGeometry
    /// Activités brèves en attente : la première est affichée, puis retirée à la fin de sa durée.
    @Published private(set) var transientQueue: [any Activity] = []

    let media = MediaManager()
    let battery = BatteryManager()
    let hud = HUDManager()

    // Rayons de la forme (fermée / ouverte)
    let closedTopRadius: CGFloat = 6
    let closedBottomRadius: CGFloat = 10
    let openTopRadius: CGFloat = 14
    let openBottomRadius: CGFloat = 26

    let openSize = CGSize(width: 520, height: 180)

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
        media.track == nil ? nil : MusicActivity(media: media)
    }

    /// Branche les alertes de batterie sur la file. Séparé de `init` pour que les tests
    /// ne déclenchent ni alerte ni son selon l'état réel de la batterie.
    func startBatteryAlerts() {
        battery.onAlert = { [weak self] alert in
            self?.enqueue(BatteryAlertActivity(alert: alert))
        }
        battery.update()
    }

    func startHUD() {
        hud.onActivity = { [weak self] activity in
            self?.showImmediately(activity)
        }
        hud.start()
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
