/// Clés `@AppStorage` de l'app, regroupées ici pour éviter les fautes de frappe.
/// `@AppStorage` lit et écrit une valeur dans les préférences de l'app (`UserDefaults`).
enum SettingsKey {
    // Général
    static let expandOnHover = "expandOnHover"
    /// Temps de survol avant l'ouverture de l'île, en secondes.
    static let hoverDelay = "hoverDelay"
    static let hapticFeedback = "hapticFeedback"
    static let naturalMovement = "naturalMovement"
    static let swipeToOpen = "swipeToOpen"
    static let swipeToSkip = "swipeToSkip"
    /// Ajustement de la taille de l'encoche, en points.
    static let notchWidthOffset = "notchWidthOffset"
    static let notchHeightOffset = "notchHeightOffset"
    static let idleActivity = "idleActivity"
    /// Identifiant de l'écran choisi ; 0 signifie « automatique ».
    static let displayID = "displayID"
    static let hideInFullscreen = "hideInFullscreen"

    // Lecture en cours
    static let musicColorStyle = "musicColorStyle"
    static let musicSideButton = "musicSideButton"
    static let quickPeekEnabled = "quickPeekEnabled"
    static let quickPeekDuration = "quickPeekDuration"

    // Batterie
    static let chargeAlertEnabled = "chargeAlertEnabled"
    static let lowBatteryAlertEnabled = "lowBatteryAlertEnabled"
    /// Niveau de batterie, en pourcentage, qui déclenche l'alerte.
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let lowBatterySoundEnabled = "lowBatterySoundEnabled"
    static let batteryAlertDuration = "batteryAlertDuration"
    static let batteryHidesPercentage = "batteryHidesPercentage"

    // HUD. Désactivés par défaut : les activer déclenche la demande de permission Accessibilité.
    static let volumeHUDEnabled = "volumeHUDEnabled"
    static let brightnessHUDEnabled = "brightnessHUDEnabled"
    static let volumeHUDDuration = "volumeHUDDuration"
    static let brightnessHUDDuration = "brightnessHUDDuration"
    static let volumeBarStyle = "volumeBarStyle"
    static let brightnessBarStyle = "brightnessBarStyle"
    static let volumeAnimationSpeed = "volumeAnimationSpeed"
    static let brightnessAnimationSpeed = "brightnessAnimationSpeed"
    static let volumeShowsPercentage = "volumeShowsPercentage"
    static let brightnessShowsPercentage = "brightnessShowsPercentage"
    static let hudShowsOutputDevice = "hudShowsOutputDevice"

    // Appareils. Désactivé par défaut : l'activer déclenche la demande de permission Bluetooth.
    static let bluetoothAlertsEnabled = "bluetoothAlertsEnabled"
    static let bluetoothAlertDuration = "bluetoothAlertDuration"

    // Calendrier. Désactivé par défaut : l'activer déclenche la demande de permission Calendrier.
    static let calendarEnabled = "calendarEnabled"
    static let calendarReminderEnabled = "calendarReminderEnabled"
    /// Temps entre le rappel et le début de l'événement, en minutes.
    static let calendarReminderLead = "calendarReminderLead"
    static let calendarAlertDuration = "calendarAlertDuration"
    static let calendarSoundEnabled = "calendarSoundEnabled"
    static let hourlyChimeEnabled = "hourlyChimeEnabled"
    static let hiddenCalendarIDs = "hiddenCalendarIDs"

    // Désactivés par défaut : les activer déclenche une demande de permission.
    static let weatherEnabled = "weatherEnabled"
    static let liveWaveformEnabled = "liveWaveformEnabled"

    static let shelfEnabled = "shelfEnabled"

    // Fonctions non documentées ou privées, désactivées par défaut.
    static let focusEnabled = "focusEnabled"
    static let incomingCallsEnabled = "incomingCallsEnabled"

    static let callIndicatorEnabled = "callIndicatorEnabled"

    /// Valeurs utilisées tant que l'utilisateur n'a rien changé.
    static let defaults: [String: Any] = [
        expandOnHover: true,
        hoverDelay: 0.2,
        hapticFeedback: true,
        naturalMovement: false,
        swipeToOpen: true,
        swipeToSkip: true,
        notchWidthOffset: 0.0,
        notchHeightOffset: 0.0,
        idleActivity: IdleActivity.music.rawValue,
        displayID: 0,
        hideInFullscreen: true,
        musicColorStyle: MusicColorStyle.artwork.rawValue,
        musicSideButton: MusicSideButton.shuffle.rawValue,
        quickPeekEnabled: true,
        quickPeekDuration: 2.0,
        chargeAlertEnabled: true,
        lowBatteryAlertEnabled: true,
        lowBatteryThreshold: 20,
        lowBatterySoundEnabled: true,
        batteryAlertDuration: 3.0,
        batteryHidesPercentage: false,
        volumeHUDEnabled: false,
        brightnessHUDEnabled: false,
        volumeHUDDuration: 1.5,
        brightnessHUDDuration: 1.5,
        volumeBarStyle: HUDBarStyle.white.rawValue,
        brightnessBarStyle: HUDBarStyle.white.rawValue,
        volumeAnimationSpeed: HUDAnimationSpeed.fast.rawValue,
        brightnessAnimationSpeed: HUDAnimationSpeed.fast.rawValue,
        volumeShowsPercentage: false,
        brightnessShowsPercentage: false,
        hudShowsOutputDevice: true,
        bluetoothAlertsEnabled: false,
        bluetoothAlertDuration: 4.0,
        calendarEnabled: false,
        calendarReminderEnabled: true,
        calendarReminderLead: 10.0,
        calendarAlertDuration: 5.0,
        calendarSoundEnabled: true,
        hourlyChimeEnabled: false,
        weatherEnabled: false,
        liveWaveformEnabled: false,
        shelfEnabled: true,
        focusEnabled: false,
        incomingCallsEnabled: false,
        callIndicatorEnabled: true,
    ]
}

/// Ce que l'île affiche quand aucune activité brève n'est en cours.
enum IdleActivity: String, CaseIterable, Identifiable {
    case none, music, calendar

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Rien"
        case .music: return "Musique"
        case .calendar: return "Calendrier"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "nosign"
        case .music: return "play.fill"
        case .calendar: return "calendar"
        }
    }
}
