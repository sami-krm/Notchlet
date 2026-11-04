/// Clés `@AppStorage` de l'app, regroupées ici pour éviter les fautes de frappe.
/// `@AppStorage` lit et écrit une valeur dans les préférences de l'app (`UserDefaults`).
enum SettingsKey {
    /// Temps de survol avant l'ouverture de l'île, en secondes.
    static let hoverDelay = "hoverDelay"
    /// Identifiant de l'écran choisi ; 0 signifie « automatique ».
    static let displayID = "displayID"
    static let hideInFullscreen = "hideInFullscreen"
    static let musicColorStyle = "musicColorStyle"
    static let chargeAlertEnabled = "chargeAlertEnabled"
    static let lowBatteryAlertEnabled = "lowBatteryAlertEnabled"
    /// Niveau de batterie, en pourcentage, qui déclenche l'alerte.
    static let lowBatteryThreshold = "lowBatteryThreshold"
    static let lowBatterySoundEnabled = "lowBatterySoundEnabled"

    /// Valeurs utilisées tant que l'utilisateur n'a rien changé.
    static let defaults: [String: Any] = [
        hoverDelay: 0.2,
        displayID: 0,
        hideInFullscreen: true,
        musicColorStyle: MusicColorStyle.artwork.rawValue,
        chargeAlertEnabled: true,
        lowBatteryAlertEnabled: true,
        lowBatteryThreshold: 20,
        lowBatterySoundEnabled: true,
    ]
}
