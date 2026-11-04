import AppKit

/// Suit le mode de concentration actif.
///
/// Permission : Accès complet au disque, à accorder à la main : macOS n'affiche pas de demande.
/// La lecture ne tourne que si la fonction est activée.
@MainActor
final class FocusManager: NSObject, ObservableObject {
    @Published private(set) var mode: FocusMode?
    @Published private(set) var isDenied = false

    /// Le nouveau mode, ou `nil` si la concentration vient de s'arrêter.
    var onChange: (@MainActor (FocusMode?) -> Void)?

    private var timer: Timer?
    private var hasRead = false

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil
        )
        applySettings()
    }

    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func applySettings() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.focusEnabled)
        guard enabled != (timer != nil) else { return }
        if enabled {
            // macOS ne signale pas ce changement publiquement : une lecture toutes les 5 secondes
            // d'un petit fichier reste négligeable.
            let timer = Timer(timeInterval: 5, target: self, selector: #selector(read), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            read()
        } else {
            timer?.invalidate()
            timer = nil
            hasRead = false
            mode = nil
            isDenied = false
        }
    }

    @objc private func read() {
        Task {
            let result = await Task.detached(priority: .utility) { FocusStatus.read() }.value
            guard timer != nil else { return }
            apply(result)
        }
    }

    func apply(_ result: FocusStatus.ReadResult) {
        switch result {
        case .denied:
            isDenied = true
        case .mode(let new):
            isDenied = false
            let changed = new != mode
            mode = new
            // Le premier relevé décrit l'état au lancement : ce n'est pas un changement.
            if changed && hasRead { onChange?(new) }
            hasRead = true
        }
    }
}
