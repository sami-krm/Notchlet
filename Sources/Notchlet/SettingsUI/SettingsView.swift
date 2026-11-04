import SwiftUI

/// Une rubrique de la barre latérale. Une rubrique s'ajoute avec la fonctionnalité qu'elle règle.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general, battery, devices, brightness, volume, nowPlaying, calendar, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Général"
        case .battery: return "Batterie"
        case .devices: return "Appareils"
        case .brightness: return "Luminosité"
        case .volume: return "Volume"
        case .nowPlaying: return "Lecture en cours"
        case .calendar: return "Calendrier"
        case .about: return "À propos"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .battery: return "bolt.fill"
        case .devices: return "headphones"
        case .brightness: return "sun.max.fill"
        case .volume: return "speaker.wave.2.fill"
        case .nowPlaying: return "play.fill"
        case .calendar: return "calendar"
        case .about: return "info"
        }
    }

    var colors: [Color] {
        switch self {
        case .general: return [Color(white: 0.55), Color(white: 0.38)]
        case .battery: return [Color(red: 0.42, green: 0.85, blue: 0.45), Color(red: 0.20, green: 0.66, blue: 0.32)]
        case .devices: return [Color(red: 0.36, green: 0.68, blue: 0.98), Color(red: 0.18, green: 0.45, blue: 0.90)]
        case .brightness: return [Color(red: 1.00, green: 0.80, blue: 0.30), Color(red: 0.96, green: 0.60, blue: 0.14)]
        case .volume: return [Color(red: 0.62, green: 0.52, blue: 0.98), Color(red: 0.42, green: 0.30, blue: 0.88)]
        case .nowPlaying: return [Color(red: 1.00, green: 0.45, blue: 0.45), Color(red: 0.88, green: 0.22, blue: 0.32)]
        case .calendar: return [Color(red: 0.32, green: 0.80, blue: 0.82), Color(red: 0.12, green: 0.58, blue: 0.66)]
        case .about: return [Color(white: 0.55), Color(white: 0.38)]
        }
    }

    /// Groupes de la barre latérale, avec leur titre éventuel.
    static let groups: [(title: String?, pages: [SettingsPage])] = [
        (nil, [.general]),
        ("Notifications", [.battery, .devices, .brightness, .volume]),
        ("Activités", [.nowPlaying, .calendar]),
        ("Notchlet", [.about]),
    ]
}

struct SettingsView: View {
    let hud: HUDManager
    let bluetooth: BluetoothManager
    let calendar: CalendarManager
    @State var page: SettingsPage = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1)
            detail
        }
        .frame(width: 760, height: 580)
        .background(Color(white: 0.13))
        .foregroundStyle(.white)
        .font(.system(size: 13))
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsPage.groups, id: \.pages) { group in
                if let title = group.title {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.leading, 10)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }
                ForEach(group.pages) { item in
                    Button {
                        page = item
                    } label: {
                        HStack(spacing: 10) {
                            SettingsIcon(symbol: item.symbol, colors: item.colors, size: 22)
                            Text(item.title)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(page == item ? 0.1 : 0))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 44)
        .frame(width: 210)
        .background(Color(white: 0.10))
    }

    private var detail: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                SettingsIcon(symbol: page.symbol, colors: page.colors, size: 24)
                Text(page.title).font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 52)

            ScrollView {
                VStack(spacing: 12) {
                    switch page {
                    case .general: GeneralPage()
                    case .battery: BatteryPage()
                    case .devices: DevicesPage(bluetooth: bluetooth)
                    case .brightness: BrightnessPage(hud: hud)
                    case .volume: VolumePage(hud: hud)
                    case .nowPlaying: NowPlayingPage()
                    case .calendar: CalendarPage(calendar: calendar)
                    case .about: AboutPage()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private func seconds(_ value: Double) -> String { String(format: "%.1f s", value) }

// MARK: - Général

private struct GeneralPage: View {
    @AppStorage(SettingsKey.idleActivity) private var idleActivity = IdleActivity.music
    @AppStorage(SettingsKey.expandOnHover) private var expandOnHover = true
    @AppStorage(SettingsKey.hoverDelay) private var hoverDelay = 0.2
    @AppStorage(SettingsKey.hapticFeedback) private var hapticFeedback = true
    @AppStorage(SettingsKey.naturalMovement) private var naturalMovement = false
    @AppStorage(SettingsKey.swipeToOpen) private var swipeToOpen = true
    @AppStorage(SettingsKey.swipeToSkip) private var swipeToSkip = true
    @AppStorage(SettingsKey.notchWidthOffset) private var notchWidth = 0.0
    @AppStorage(SettingsKey.notchHeightOffset) private var notchHeight = 0.0
    @AppStorage(SettingsKey.displayID) private var displayID = 0
    @AppStorage(SettingsKey.hideInFullscreen) private var hideInFullscreen = true
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some View {
        SettingsSectionTitle(title: "Démarrage")
        SettingsCard {
            SettingsToggleRow(title: "Lancer à l'ouverture de session", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            if launchAtLogin.needsApproval {
                SettingsDivider()
                HStack {
                    Text("macOS attend ton accord.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Ouvrir Réglages Système") { launchAtLogin.openSystemSettings() }
                }
                .padding(14)
            }
            if let error = launchAtLogin.errorMessage {
                SettingsDivider()
                Text(error).foregroundStyle(.red).padding(14)
            }
        }

        SettingsSectionTitle(title: "Au repos")
        SettingsCard {
            SettingsTilePicker(options: IdleActivity.allCases, selection: $idleActivity, label: \.label) { option in
                Image(systemName: option.symbol).font(.system(size: 18, weight: .semibold))
            }
        }

        SettingsSectionTitle(title: "Comportement")
        SettingsCard {
            // Le survol et le balayage sont les seuls moyens d'ouvrir l'île : on garde l'un des deux.
            SettingsToggleRow(title: "Ouvrir au survol", isOn: $expandOnHover)
                .disabled(expandOnHover && !swipeToOpen)
            if expandOnHover {
                SettingsDivider()
                SettingsSliderRow(title: "Délai de survol", value: $hoverDelay, range: 0...1, step: 0.1, format: seconds)
            }
            SettingsDivider()
            SettingsToggleRow(title: "Retour haptique", isOn: $hapticFeedback)
            SettingsDivider()
            SettingsToggleRow(title: "Masquer l'île en plein écran", isOn: $hideInFullscreen)
            SettingsDivider()
            HStack {
                Text("Écran")
                Spacer()
                Picker("Écran", selection: $displayID) {
                    Text("Automatique").tag(0)
                    ForEach(NSScreen.screens, id: \.displayID) { screen in
                        Text(screen.localizedName).tag(screen.displayID)
                    }
                    if displayID != 0, !NSScreen.screens.contains(where: { $0.displayID == displayID }) {
                        Text("Écran débranché").tag(displayID)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
        }

        SettingsSectionTitle(title: "Gestes au trackpad")
        SettingsCard {
            SettingsToggleRow(title: "Mouvement inversé", isOn: $naturalMovement)
            SettingsDivider()
            SettingsToggleRow(title: "Balayer pour ouvrir ou fermer", isOn: $swipeToOpen)
                .disabled(swipeToOpen && !expandOnHover)
            SettingsDivider()
            SettingsToggleRow(title: "Balayer pour changer de morceau", isOn: $swipeToSkip)
        }

        SettingsSectionTitle(title: "Ajustement de l'encoche")
        SettingsCard {
            SettingsSliderRow(title: "Largeur", value: $notchWidth, range: -30...30, step: 1) { String(format: "%.0f pt", $0) }
            SettingsDivider()
            SettingsSliderRow(title: "Hauteur", value: $notchHeight, range: -10...10, step: 1) { String(format: "%.0f pt", $0) }
        }
    }
}

// MARK: - Batterie

private struct BatteryPage: View {
    @AppStorage(SettingsKey.chargeAlertEnabled) private var chargeAlert = true
    @AppStorage(SettingsKey.lowBatteryAlertEnabled) private var lowAlert = true
    @AppStorage(SettingsKey.lowBatteryThreshold) private var threshold = 20
    @AppStorage(SettingsKey.lowBatterySoundEnabled) private var sound = true
    @AppStorage(SettingsKey.batteryAlertDuration) private var duration = 3.0
    @AppStorage(SettingsKey.batteryHidesPercentage) private var hidesPercentage = false

    var body: some View {
        SettingsCard {
            SettingsToggleRow(title: "Alerter au branchement du chargeur", isOn: $chargeAlert)
            SettingsDivider()
            SettingsSliderRow(title: "Durée d'affichage", value: $duration, range: 1...10, step: 0.5, format: seconds)
            SettingsDivider()
            SettingsToggleRow(title: "Alerter quand la batterie est faible", isOn: $lowAlert)
            if lowAlert {
                SettingsDivider()
                SettingsSliderRow(
                    title: "Seuil de batterie faible",
                    // `Slider` travaille avec des décimaux, le réglage est un entier.
                    value: Binding(get: { Double(threshold) }, set: { threshold = Int($0) }),
                    range: 5...50, step: 5
                ) { String(format: "%.0f %%", $0) }
                SettingsDivider()
                SettingsToggleRow(title: "Jouer un son", isOn: $sound)
            }
            SettingsDivider()
            SettingsToggleRow(title: "Masquer le pourcentage", isOn: $hidesPercentage)
        }
    }
}

// MARK: - Appareils

private struct DevicesPage: View {
    @ObservedObject var bluetooth: BluetoothManager
    @AppStorage(SettingsKey.bluetoothAlertsEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.bluetoothAlertDuration) private var duration = 4.0

    var body: some View {
        SettingsCard {
            SettingsToggleRow(title: "Signaler la connexion des appareils", isOn: $isEnabled)
                .onChange(of: isEnabled) { enabled in
                    if enabled && bluetooth.authorization == .notDetermined { bluetooth.requestPermission() }
                }
            if isEnabled && (bluetooth.authorization == .denied || bluetooth.authorization == .restricted) {
                SettingsDivider()
                PermissionRow(
                    message: "Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Bluetooth.",
                    action: bluetooth.openPermissionSettings
                )
            }
            SettingsDivider()
            SettingsSliderRow(title: "Durée d'affichage", value: $duration, range: 1...10, step: 0.5, format: seconds)
        }
        Text("Pour des écouteurs, l'île affiche le niveau le plus faible des deux.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PermissionRow: View {
    let message: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).foregroundStyle(.secondary)
            Button("Ouvrir Réglages Système", action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

// MARK: - Luminosité et volume

/// Réglages communs aux deux HUD.
private struct HUDAppearanceRows: View {
    @Binding var style: HUDBarStyle
    @Binding var speed: HUDAnimationSpeed
    @Binding var showsPercentage: Bool

    var body: some View {
        SettingsTilePicker(options: HUDBarStyle.allCases, selection: $style, label: \.label) { option in
            switch option {
            case .white: BarPreview(colors: [.white, .white])
            case .accent: BarPreview(colors: [NotchletStyle.accent, NotchletStyle.accent])
            case .glow: BarPreview(colors: [.white, .white], glow: true)
            }
        }
        SettingsDivider()
        SettingsToggleRow(title: "Afficher le pourcentage", isOn: $showsPercentage)
        SettingsDivider()
        SettingsTilePicker(options: HUDAnimationSpeed.allCases, selection: $speed, label: \.label) { option in
            Image(systemName: option.symbol).font(.system(size: 16, weight: .semibold))
        }
    }
}

private struct BrightnessPage: View {
    @ObservedObject var hud: HUDManager
    @AppStorage(SettingsKey.brightnessHUDEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.brightnessHUDDuration) private var duration = 1.5
    @AppStorage(SettingsKey.brightnessBarStyle) private var style = HUDBarStyle.white
    @AppStorage(SettingsKey.brightnessAnimationSpeed) private var speed = HUDAnimationSpeed.fast
    @AppStorage(SettingsKey.brightnessShowsPercentage) private var showsPercentage = false

    var body: some View {
        SettingsCard {
            SettingsToggleRow(title: "Remplacer le HUD de luminosité", isOn: $isEnabled)
                .onChange(of: isEnabled) { enabled in
                    if enabled && !hud.isTrusted { hud.requestPermission() }
                }
            if isEnabled && !hud.isTrusted {
                SettingsDivider()
                PermissionRow(
                    message: "Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Accessibilité.",
                    action: hud.openPermissionSettings
                )
            }
            SettingsDivider()
            SettingsSliderRow(title: "Durée d'affichage", value: $duration, range: 0.5...5, step: 0.5, format: seconds)
            SettingsDivider()
            HUDAppearanceRows(style: $style, speed: $speed, showsPercentage: $showsPercentage)
        }
        Text("La luminosité repose sur une API privée d'Apple. Si elle cesse de fonctionner, macOS reprend la main sur ces touches.")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VolumePage: View {
    @ObservedObject var hud: HUDManager
    @AppStorage(SettingsKey.volumeHUDEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.volumeHUDDuration) private var duration = 1.5
    @AppStorage(SettingsKey.volumeBarStyle) private var style = HUDBarStyle.white
    @AppStorage(SettingsKey.volumeAnimationSpeed) private var speed = HUDAnimationSpeed.fast
    @AppStorage(SettingsKey.volumeShowsPercentage) private var showsPercentage = false
    @AppStorage(SettingsKey.hudShowsOutputDevice) private var showsDevice = true

    var body: some View {
        SettingsCard {
            SettingsToggleRow(title: "Remplacer le HUD de volume", isOn: $isEnabled)
                .onChange(of: isEnabled) { enabled in
                    if enabled && !hud.isTrusted { hud.requestPermission() }
                }
            if isEnabled && !hud.isTrusted {
                SettingsDivider()
                PermissionRow(
                    message: "Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Accessibilité.",
                    action: hud.openPermissionSettings
                )
            }
            SettingsDivider()
            SettingsSliderRow(title: "Durée d'affichage", value: $duration, range: 0.5...5, step: 0.5, format: seconds)
            SettingsDivider()
            HUDAppearanceRows(style: $style, speed: $speed, showsPercentage: $showsPercentage)
            SettingsDivider()
            SettingsToggleRow(title: "Afficher la sortie audio", isOn: $showsDevice)
        }
    }
}

// MARK: - Lecture en cours

private struct NowPlayingPage: View {
    @AppStorage(SettingsKey.musicColorStyle) private var style = MusicColorStyle.artwork
    @AppStorage(SettingsKey.musicSideButton) private var sideButton = MusicSideButton.shuffle
    @AppStorage(SettingsKey.quickPeekEnabled) private var quickPeek = true
    @AppStorage(SettingsKey.quickPeekDuration) private var peekDuration = 2.0

    var body: some View {
        SettingsSectionTitle(title: "Style de couleur")
        SettingsCard {
            SettingsTilePicker(options: MusicColorStyle.allCases, selection: $style, label: \.label) { option in
                switch option {
                case .artwork: BarPreview(colors: [.orange, .purple])
                case .colored: BarPreview(colors: [NotchletStyle.accent, NotchletStyle.accent])
                case .gradient:
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [.black, NotchletStyle.accent], startPoint: .top, endPoint: .bottom))
                        .frame(width: 56, height: 26)
                case .monochrome: BarPreview(colors: [Color(white: 0.7), Color(white: 0.7)])
                }
            }
        }

        SettingsSectionTitle(title: "Bouton à gauche des commandes")
        SettingsCard {
            SettingsTilePicker(options: MusicSideButton.allCases, selection: $sideButton, label: \.label) { option in
                Image(systemName: option.symbol).font(.system(size: 16, weight: .semibold))
            }
        }

        SettingsSectionTitle(title: "Aperçu rapide")
        SettingsCard {
            SettingsToggleRow(title: "Ouvrir l'île quand le morceau change", isOn: $quickPeek)
            if quickPeek {
                SettingsDivider()
                SettingsSliderRow(title: "Durée de l'aperçu", value: $peekDuration, range: 1...5, step: 0.5, format: seconds)
            }
        }
    }
}

// MARK: - Calendrier

private struct CalendarPage: View {
    @ObservedObject var calendar: CalendarManager
    @AppStorage(SettingsKey.calendarEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.calendarReminderEnabled) private var reminderEnabled = true
    @AppStorage(SettingsKey.calendarReminderLead) private var lead = 10.0
    @AppStorage(SettingsKey.calendarAlertDuration) private var duration = 5.0
    @AppStorage(SettingsKey.calendarSoundEnabled) private var sound = true
    @AppStorage(SettingsKey.hourlyChimeEnabled) private var hourlyChime = false

    var body: some View {
        SettingsCard {
            SettingsToggleRow(title: "Afficher les événements dans l'île", isOn: $isEnabled)
                .onChange(of: isEnabled) { enabled in
                    if enabled && !calendar.isAuthorized { calendar.requestAccess() }
                }
            if isEnabled && calendar.isDenied {
                SettingsDivider()
                PermissionRow(
                    message: "Autorise Notchlet dans Réglages Système > Confidentialité et sécurité > Calendriers.",
                    action: calendar.openPermissionSettings
                )
            }
        }

        SettingsSectionTitle(title: "Rappels")
        SettingsCard {
            SettingsToggleRow(title: "Rappeler avant un événement", isOn: $reminderEnabled)
            if reminderEnabled {
                SettingsDivider()
                SettingsSliderRow(title: "Délai du rappel", value: $lead, range: 1...30, step: 1) {
                    String(format: "%.0f min", $0)
                }
                SettingsDivider()
                SettingsSliderRow(title: "Durée d'affichage", value: $duration, range: 1...10, step: 0.5, format: seconds)
                SettingsDivider()
                SettingsToggleRow(title: "Jouer un son", isOn: $sound)
            }
        }
        .disabled(!isEnabled)

        SettingsSectionTitle(title: "Carillon")
        SettingsCard {
            SettingsToggleRow(title: "Sonner à chaque heure", isOn: $hourlyChime)
        }

        if isEnabled && !calendar.calendars.isEmpty {
            SettingsSectionTitle(title: "Calendriers")
            SettingsCard {
                ForEach(Array(calendar.calendars.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { SettingsDivider() }
                    HStack(spacing: 10) {
                        Circle().fill(Color(cgColor: item.color)).frame(width: 10, height: 10)
                        SettingsToggleRow(title: item.title, isOn: Binding(
                            get: { calendar.isVisible(item) },
                            set: { calendar.setVisible($0, calendar: item) }
                        ))
                        .padding(.horizontal, -14)
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
    }
}

// MARK: - À propos

private struct AboutPage: View {
    private static let repository = "https://github.com/sami-krm/Notchlet"

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        SettingsCard {
            HStack {
                Text("Version")
                Spacer()
                Text(version)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            SettingsDivider()
            AboutLink(title: "Voir les versions publiées", address: Self.repository + "/releases")
            SettingsDivider()
            AboutLink(title: "Signaler un problème ou proposer une idée", address: Self.repository + "/issues")
            SettingsDivider()
            AboutLink(title: "Lire le code source", address: Self.repository)
        }
    }
}

private struct AboutLink: View {
    let title: String
    let address: String

    var body: some View {
        if let url = URL(string: address) {
            Link(destination: url) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
