import SwiftUI

/// Les autres onglets arriveront avec leurs fonctionnalités.
struct SettingsView: View {
    let hud: HUDManager
    let bluetooth: BluetoothManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("Général", systemImage: "gearshape") }
            HUDSettingsView(hud: hud)
                .tabItem { Label("HUD", systemImage: "speaker.wave.2") }
            NowPlayingSettingsView()
                .tabItem { Label("Lecture en cours", systemImage: "music.note") }
            BatterySettingsView()
                .tabItem { Label("Batterie", systemImage: "battery.75") }
            BluetoothSettingsView(bluetooth: bluetooth)
                .tabItem { Label("Bluetooth", systemImage: "airpodspro") }
            AboutView()
                .tabItem { Label("À propos", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 340)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.hoverDelay) private var hoverDelay = 0.2
    @AppStorage(SettingsKey.displayID) private var displayID = 0
    @AppStorage(SettingsKey.hideInFullscreen) private var hideInFullscreen = true
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some View {
        Form {
            Section("Démarrage") {
                Toggle("Lancer à l'ouverture de session", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.needsApproval {
                    Text("macOS attend ton accord pour lancer l'app à l'ouverture de session.")
                        .foregroundStyle(.secondary)
                    Button("Ouvrir Réglages Système") { launchAtLogin.openSystemSettings() }
                }
                if let error = launchAtLogin.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("Île") {
                LabeledContent("Délai de survol : \(hoverDelay, specifier: "%.1f") s") {
                    Slider(value: $hoverDelay, in: 0...1, step: 0.1)
                }
                Picker("Écran", selection: $displayID) {
                    Text("Automatique").tag(0)
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                    if displayID != 0, !NSScreen.screens.contains(where: { $0.displayID == displayID }) {
                        Text("Écran débranché").tag(displayID)
                    }
                }
                Toggle("Masquer l'île en plein écran", isOn: $hideInFullscreen)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

private struct HUDSettingsView: View {
    @ObservedObject var hud: HUDManager
    @AppStorage(SettingsKey.hudEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.brightnessHUDEnabled) private var brightnessEnabled = true
    @AppStorage(SettingsKey.hudBarStyle) private var barStyle = HUDBarStyle.white
    @AppStorage(SettingsKey.hudAnimationSpeed) private var speed = HUDAnimationSpeed.fast
    @AppStorage(SettingsKey.hudShowsOutputDevice) private var showsDevice = true

    var body: some View {
        Form {
            Section {
                Toggle("Remplacer les HUD de macOS", isOn: $isEnabled)
                    .onChange(of: isEnabled) { enabled in
                        if enabled && !hud.isTrusted { hud.requestPermission() }
                    }
                if isEnabled && !hud.isTrusted {
                    Text("Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Accessibilité.")
                        .foregroundStyle(.secondary)
                    Button("Ouvrir Réglages Système") { hud.openPermissionSettings() }
                }
                Toggle("Inclure la luminosité", isOn: $brightnessEnabled)
                    .disabled(!isEnabled)
            } footer: {
                Text("La luminosité repose sur une API privée d'Apple. Si elle cesse de fonctionner, macOS reprend la main sur ces touches.")
                    .foregroundStyle(.secondary)
            }

            Section("Apparence") {
                Picker("Barre", selection: $barStyle) {
                    ForEach(HUDBarStyle.allCases) { Text($0.label).tag($0) }
                }
                Picker("Animation", selection: $speed) {
                    ForEach(HUDAnimationSpeed.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Afficher la sortie audio", isOn: $showsDevice)
            }
            .disabled(!isEnabled)
        }
        .formStyle(.grouped)
    }
}

private struct NowPlayingSettingsView: View {
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork

    var body: some View {
        Form {
            Picker("Style de couleur", selection: $style) {
                ForEach(MusicColorStyle.allCases) { Text($0.label).tag($0) }
            }
            Section("Gestes au trackpad, à deux doigts sur l'île") {
                LabeledContent("Vers le bas ou le haut", value: "Ouvrir ou fermer")
                LabeledContent("Vers la gauche ou la droite", value: "Morceau suivant ou précédent")
            }
        }
        .formStyle(.grouped)
    }
}

private struct BatterySettingsView: View {
    @AppStorage(SettingsKey.chargeAlertEnabled) private var chargeAlertEnabled = true
    @AppStorage(SettingsKey.lowBatteryAlertEnabled) private var lowAlertEnabled = true
    @AppStorage(SettingsKey.lowBatteryThreshold) private var threshold = 20
    @AppStorage(SettingsKey.lowBatterySoundEnabled) private var soundEnabled = true

    var body: some View {
        Form {
            Section("Charge") {
                Toggle("Alerter au branchement du chargeur", isOn: $chargeAlertEnabled)
            }
            Section("Batterie faible") {
                Toggle("Alerter quand la batterie est faible", isOn: $lowAlertEnabled)
                LabeledContent("Seuil : \(threshold) %") {
                    // `Slider` travaille avec des nombres décimaux, le réglage est un entier.
                    Slider(value: Binding(get: { Double(threshold) }, set: { threshold = Int($0) }),
                           in: 5...50, step: 5)
                }
                .disabled(!lowAlertEnabled)
                Toggle("Jouer un son", isOn: $soundEnabled)
                    .disabled(!lowAlertEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

private struct BluetoothSettingsView: View {
    @ObservedObject var bluetooth: BluetoothManager
    @AppStorage(SettingsKey.bluetoothAlertsEnabled) private var isEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("Signaler la connexion des appareils", isOn: $isEnabled)
                    .onChange(of: isEnabled) { enabled in
                        if enabled && bluetooth.authorization == .notDetermined { bluetooth.requestPermission() }
                    }
                if isEnabled && (bluetooth.authorization == .denied || bluetooth.authorization == .restricted) {
                    Text("Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Bluetooth.")
                        .foregroundStyle(.secondary)
                    Button("Ouvrir Réglages Système") { bluetooth.openPermissionSettings() }
                }
            } footer: {
                Text("L'île affiche l'appareil et sa batterie. Pour des écouteurs, c'est le niveau le plus faible des deux.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "capsule.fill")
                .font(.system(size: 40))
            Text("Notchlet")
                .font(.title2.weight(.semibold))
            Text("Version \(version)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
