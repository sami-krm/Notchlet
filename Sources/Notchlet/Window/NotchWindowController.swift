import AppKit
import SwiftUI

/// NSHostingView qui accepte le premier clic : les boutons marchent
/// sans devoir d'abord "activer" la fenêtre.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class NotchWindowController: NSObject {
    /// Taille fixe de la fenêtre transparente (plus grande que l'île ouverte).
    private static let windowSize = CGSize(width: 680, height: 280)

    private let panel: NSPanel
    private let viewModel: NotchViewModel
    private var screen: NSScreen
    private var mouseTimer: Timer?
    private var hoverTimer = HoverTimer()
    /// Balayage en cours, s'il a commencé sur l'île.
    private var swipe: SwipeDetector?
    /// Après une fermeture par balayage, la souris doit quitter la zone : sinon le survol
    /// rouvrirait l'île aussitôt.
    private var hoverBlocked = false
    private var scrollMonitors: [Any] = []

    override init() {
        screen = NotchGeometry.targetScreen()
        viewModel = NotchViewModel(geometry: .from(screen))

        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        // Au-dessus de la barre des menus pour recouvrir l'encoche.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        // Fermée, l'île laisse passer les clics (la barre des menus reste utilisable).
        panel.ignoresMouseEvents = true

        let host = NotchHostingView(rootView: NotchView(
            vm: viewModel,
            media: viewModel.media,
            battery: viewModel.battery
        ))
        host.sizingOptions = []
        panel.contentView = host

        // Un réglage vient de changer : on l'applique tout de suite.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applySettings),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    func show() {
        applySettings()
        panel.orderFrontRegardless()
        startMouseTracking()
        startSwipeTracking()
        viewModel.startBatteryAlerts()
        viewModel.startHUD()
        viewModel.startBluetooth()
    }

    var hud: HUDManager { viewModel.hud }
    var bluetooth: BluetoothManager { viewModel.bluetooth }

    @objc private func applySettings() {
        // Sans `.fullScreenAuxiliary`, macOS n'affiche pas la fenêtre dans les espaces plein écran.
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if !UserDefaults.standard.bool(forKey: SettingsKey.hideInFullscreen) {
            behavior.insert(.fullScreenAuxiliary)
        }
        panel.collectionBehavior = behavior
        reposition()
    }

    func reposition() {
        screen = NotchGeometry.targetScreen()
        viewModel.geometry = .from(screen)

        let size = Self.windowSize
        let frame = screen.frame
        panel.setFrame(
            NSRect(x: frame.midX - size.width / 2,
                   y: frame.maxY - size.height,
                   width: size.width,
                   height: size.height),
            display: true
        )
    }

    // MARK: - Survol de la souris

    /// On interroge la position de la souris 10 fois/s : simple, sans permission
    /// d'accessibilité, et quasi gratuit en CPU.
    private func startMouseTracking() {
        let timer = Timer(timeInterval: 0.1, target: self,
                          selector: #selector(pollMouse), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer
    }

    @objc private func pollMouse() {
        // Île masquée (plein écran) : le survol ne doit rien déclencher.
        guard panel.isOnActiveSpace else { return }
        let isInZone = activeZone.contains(NSEvent.mouseLocation)

        switch viewModel.state {
        case .closed:
            if !isInZone { hoverBlocked = false }
            let delay = UserDefaults.standard.double(forKey: SettingsKey.hoverDelay)
            if hoverTimer.update(isInside: isInZone && !hoverBlocked, now: Date(), delay: delay) {
                setState(.open)
            }

        case .open:
            if !isInZone { setState(.closed) }
        }
    }

    /// Zone où la souris agit sur l'île : un peu plus large que l'île elle-même.
    private var activeZone: NSRect {
        let frame = screen.frame
        switch viewModel.state {
        case .closed:
            let size = viewModel.closedSize
            return NSRect(x: frame.midX - size.width / 2 - 10,
                          y: frame.maxY - size.height - 4,
                          width: size.width + 20,
                          height: size.height + 10)
        case .open:
            let size = viewModel.openSize
            return NSRect(x: frame.midX - size.width / 2 - 24,
                          y: frame.maxY - size.height - 24,
                          width: size.width + 48,
                          height: size.height + 30)
        }
    }

    private func setState(_ newState: NotchViewModel.State) {
        guard viewModel.state != newState else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            viewModel.state = newState
        }
        panel.ignoresMouseEvents = (newState == .closed)
        if newState == .open { viewModel.media.refreshProgress() }
    }

    // MARK: - Gestes au trackpad

    /// Île fermée, la fenêtre ignore la souris : le moniteur global voit le défilement
    /// destiné aux autres apps. Île ouverte, c'est le moniteur local qui le reçoit.
    /// Suivre le défilement ne demande pas la permission Accessibilité.
    private func startSwipeTracking() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
        scrollMonitors = [global, local].compactMap { $0 }
    }

    private func handleScroll(_ event: NSEvent) {
        // `hasPreciseScrollingDeltas` écarte la molette ; `momentumPhase` écarte l'inertie
        // qui continue après que les doigts ont quitté le trackpad.
        guard panel.isOnActiveSpace, event.hasPreciseScrollingDeltas, event.momentumPhase == [] else { return }

        if event.phase == .began {
            swipe = activeZone.contains(NSEvent.mouseLocation) ? SwipeDetector() : nil
        }
        // Avec le défilement naturel, le signe des valeurs suit les doigts ; sinon il est inversé.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let detected = swipe?.update(fingerX: event.scrollingDeltaX * sign,
                                     fingerY: event.scrollingDeltaY * sign)
        switch detected {
        case .down:
            setState(.open)
        case .up:
            hoverBlocked = true
            setState(.closed)
        case .left:
            viewModel.media.next()
        case .right:
            viewModel.media.previous()
        case nil:
            break
        }
    }
}
