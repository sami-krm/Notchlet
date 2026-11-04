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

    // Rayons de la forme (fermée / ouverte)
    let closedTopRadius: CGFloat = 6
    let closedBottomRadius: CGFloat = 10
    let openTopRadius: CGFloat = 14
    let openBottomRadius: CGFloat = 26

    /// Largeur ajoutée de chaque côté de l'encoche quand une "live activity" tourne.
    let activityWing: CGFloat = 34

    let openSize = CGSize(width: 520, height: 180)

    private var transientTimer: Timer?

    init(geometry: NotchGeometry) {
        self.geometry = geometry
    }

    var topRadius: CGFloat { state == .open ? openTopRadius : closedTopRadius }
    var bottomRadius: CGFloat { state == .open ? openBottomRadius : closedBottomRadius }

    var closedSize: CGSize {
        var width = geometry.notchSize.width + 2 * closedTopRadius
        if displayed != nil { width += 2 * activityWing }
        return CGSize(width: width, height: geometry.notchSize.height)
    }

    var currentSize: CGSize { state == .open ? openSize : closedSize }

    // MARK: - Activités

    /// Une activité brève passe avant l'activité de fond, puis celle-ci revient.
    var displayed: (any Activity)? { transientQueue.first ?? background }

    private var background: (any Activity)? {
        media.track == nil ? nil : MusicActivity(media: media)
    }

    func enqueue(_ activity: any Activity) {
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
        guard let current = transientQueue.first else { return }
        let timer = Timer(timeInterval: current.displayDuration, target: self,
                          selector: #selector(finishCurrentTransient), userInfo: nil, repeats: false)
        // Mode `.common` : le timer continue de tourner pendant un survol ou un défilement.
        RunLoop.main.add(timer, forMode: .common)
        transientTimer = timer
    }
}
