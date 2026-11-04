import SwiftUI

/// Les autres onglets arriveront avec leurs fonctionnalités.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("Général", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("À propos", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 340)
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

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "capsule.fill")
                .font(.system(size: 40))
            Text("DynamicNotch")
                .font(.title2.weight(.semibold))
            Text("Version \(version)")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
