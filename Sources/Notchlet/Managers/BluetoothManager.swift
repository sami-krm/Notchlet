import AppKit
import CoreBluetooth
import IOBluetooth

/// Niveaux de batterie d'un appareil, en pourcentage.
struct BluetoothBattery: Equatable {
    var left: Int?
    var right: Int?
    var boxCase: Int?
    var main: Int?

    /// Niveau à afficher : celui de l'écouteur le plus faible, ou celui de l'appareil.
    var displayed: Int? { [left, right].compactMap { $0 }.min() ?? main }
}

/// Ce que `system_profiler` indique sur un appareil connecté.
struct BluetoothDeviceReport: Equatable {
    var battery: BluetoothBattery
    var minorType: String?

    /// Cherche l'appareil dans le JSON de `system_profiler SPBluetoothDataType -json`.
    /// Ce format n'est pas documenté : un champ absent donne simplement un niveau inconnu.
    static func parse(_ data: Data, address: String) -> BluetoothDeviceReport? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let blocks = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return nil }

        let target = normalized(address)
        for block in blocks {
            for entry in block["device_connected"] as? [[String: Any]] ?? [] {
                for case let info as [String: Any] in entry.values {
                    guard let found = info["device_address"] as? String, normalized(found) == target
                    else { continue }
                    return BluetoothDeviceReport(
                        battery: BluetoothBattery(
                            left: percent(info["device_batteryLevelLeft"]),
                            right: percent(info["device_batteryLevelRight"]),
                            boxCase: percent(info["device_batteryLevelCase"]),
                            main: percent(info["device_batteryLevelMain"])
                        ),
                        minorType: info["device_minorType"] as? String
                    )
                }
            }
        }
        return nil
    }

    /// IOBluetooth écrit `aa-bb-cc`, `system_profiler` écrit `AA:BB:CC`.
    private static func normalized(_ address: String) -> String {
        address.uppercased().replacingOccurrences(of: "-", with: ":")
    }

    /// La valeur ressemble à "80 %" avec une espace insécable : on ne garde que les chiffres.
    private static func percent(_ value: Any?) -> Int? {
        (value as? String).flatMap { Int($0.filter(\.isNumber)) }
    }
}

/// Évite les alertes en trop : macOS signale aussi les appareils déjà connectés au moment
/// de l'inscription, et des AirPods peuvent se reconnecter plusieurs fois de suite.
struct BluetoothAlertFilter {
    private var startedAt: Date
    private var lastAlerts: [String: Date] = [:]

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    mutating func shouldAlert(address: String, now: Date) -> Bool {
        guard now.timeIntervalSince(startedAt) >= 2 else { return false }
        if let last = lastAlerts[address], now.timeIntervalSince(last) < 15 { return false }
        lastAlerts[address] = now
        return true
    }
}

/// Signale la connexion d'un appareil Bluetooth, avec sa batterie.
///
/// Connexions : IOBluetooth (API publique, permission Bluetooth).
/// Batterie : l'outil système `system_profiler`, car IOBluetooth ne la fournit pas publiquement.
@MainActor
final class BluetoothManager: NSObject, ObservableObject {
    @Published private(set) var authorization = CBManager.authorization

    var onActivity: (@MainActor (BluetoothActivity) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var alertFilter = BluetoothAlertFilter(startedAt: .distantPast)
    private var permissionTimer: Timer?
    /// Sa seule création fait apparaître la demande de permission de macOS.
    private var permissionRequester: CBCentralManager?

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil
        )
        applySettings()
    }

    func requestPermission() {
        permissionRequester = CBCentralManager(delegate: nil, queue: nil)
    }

    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
        else { return }
        NSWorkspace.shared.open(url)
    }

    /// Appelée aussi régulièrement tant que la fonction est activée : macOS ne prévient pas
    /// quand la permission change.
    @objc private func applySettings() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.bluetoothAlertsEnabled)
        let current = CBManager.authorization
        if current != authorization { authorization = current }

        if enabled && current == .allowedAlways {
            startListening()
        } else {
            stopListening()
        }

        if enabled, permissionTimer == nil {
            let timer = Timer(timeInterval: 2, target: self, selector: #selector(applySettings),
                              userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            permissionTimer = timer
        } else if !enabled {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func startListening() {
        guard connectNotification == nil else { return }
        alertFilter = BluetoothAlertFilter(startedAt: Date())
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self, selector: #selector(deviceConnected(_:device:))
        )
    }

    private func stopListening() {
        connectNotification?.unregister()
        connectNotification = nil
    }

    /// macOS envoie plusieurs signaux par connexion, parfois sur un thread secondaire : on lit
    /// l'appareil ici, puis on repasse sur le thread principal, seul autorisé à toucher à
    /// l'état de cette classe.
    @objc private nonisolated func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        let name = device.nameOrAddress ?? "Appareil Bluetooth"
        Task { @MainActor in self.handleConnection(address: address, name: name) }
    }

    private func handleConnection(address: String, name: String) {
        guard alertFilter.shouldAlert(address: address, now: Date()) else { return }
        Task {
            let report = await Self.waitForReport(address: address)
            onActivity?(BluetoothActivity(deviceName: name, battery: report?.battery ?? BluetoothBattery(),
                                          minorType: report?.minorType))
        }
    }

    /// La batterie n'est connue qu'un peu après la connexion : on réessaie quelques fois,
    /// puis on affiche l'appareil sans niveau.
    private nonisolated static func waitForReport(address: String) async -> BluetoothDeviceReport? {
        var report: BluetoothDeviceReport?
        for attempt in 0..<3 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 1_500_000_000) }
            if let data = await runSystemProfiler() {
                report = BluetoothDeviceReport.parse(data, address: address)
            }
            if report?.battery.displayed != nil { break }
        }
        return report
    }

    /// Hors du thread principal, comme tout lancement de processus.
    private nonisolated static func runSystemProfiler() async -> Data? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
                process.arguments = ["SPBluetoothDataType", "-json"]
                process.standardOutput = output
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0 ? data : nil)
            }
        }
    }
}
