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
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        // Fermée, l'île laisse passer les clics (la barre des menus reste utilisable).
        panel.ignoresMouseEvents = true

        let host = NotchHostingView(rootView: NotchView(
            vm: viewModel,
            media: viewModel.media,
            battery: viewModel.battery
        ))
        host.sizingOptions = []
        panel.contentView = host
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
        startMouseTracking()
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
        let mouse = NSEvent.mouseLocation
        let frame = screen.frame

        switch viewModel.state {
        case .closed:
            let size = viewModel.closedSize
            let hotZone = NSRect(x: frame.midX - size.width / 2 - 10,
                                 y: frame.maxY - size.height - 4,
                                 width: size.width + 20,
                                 height: size.height + 10)
            if hotZone.contains(mouse) { setState(.open) }

        case .open:
            let size = viewModel.openSize
            let keepZone = NSRect(x: frame.midX - size.width / 2 - 24,
                                  y: frame.maxY - size.height - 24,
                                  width: size.width + 48,
                                  height: size.height + 30)
            if !keepZone.contains(mouse) { setState(.closed) }
        }
    }

    private func setState(_ newState: NotchViewModel.State) {
        guard viewModel.state != newState else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            viewModel.state = newState
        }
        panel.ignoresMouseEvents = (newState == .closed)
    }
}
