import AppKit
import CoreLocation

/// Météo actuelle, avec les codes WMO utilisés par Open-Meteo.
struct WeatherReport: Equatable {
    let temperature: Double
    let code: Int

    var symbol: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var label: String {
        switch code {
        case 0: return "Ciel dégagé"
        case 1, 2: return "Partiellement nuageux"
        case 45, 48: return "Brouillard"
        case 51...57: return "Bruine"
        case 61...67, 80...82: return "Pluie"
        case 71...77, 85, 86: return "Neige"
        case 95...99: return "Orage"
        default: return "Couvert"
        }
    }

    var temperatureText: String { "\(Int(temperature.rounded()))°" }

    /// Lit la réponse d'Open-Meteo. Une réponse invalide donne `nil`.
    static func parse(_ data: Data) -> WeatherReport? {
        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double
                let weather_code: Int
            }
            let current: Current
        }
        guard let current = try? JSONDecoder().decode(Response.self, from: data).current else { return nil }
        return WeatherReport(temperature: current.temperature_2m, code: current.weather_code)
    }
}

enum WeatherAPI {
    /// La position est arrondie à 0,01° (environ 1 km) : assez pour la météo, sans envoyer
    /// l'adresse exacte à un service tiers.
    static func url(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        return components?.url
    }
}

/// Météo locale, via CoreLocation et Open-Meteo.
///
/// Permission : Localisation, demandée quand on active la rubrique.
@MainActor
final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var report: WeatherReport?
    @Published private(set) var isDenied = false
    @Published private(set) var errorMessage: String?

    private let locationManager = CLLocationManager()
    private var timer: Timer?
    private var isRunning = false

    func start() {
        locationManager.delegate = self
        // Une précision grossière suffit, et ménage la batterie.
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        NotificationCenter.default.addObserver(
            self, selector: #selector(applySettings), name: UserDefaults.didChangeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(update), name: NSWorkspace.didWakeNotification, object: nil
        )
        applySettings()
    }

    func openPermissionSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")
        else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func applySettings() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.weatherEnabled)
        guard enabled != isRunning else { return }
        isRunning = enabled
        timer?.invalidate()
        guard enabled else {
            report = nil
            errorMessage = nil
            return
        }
        // Le temps change lentement : une lecture par demi-heure suffit.
        let timer = Timer(timeInterval: 1800, target: self, selector: #selector(update), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    @objc private func update() {
        guard isRunning else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isDenied = true
        default:
            isDenied = false
            locationManager.requestLocation()
        }
    }

    // CoreLocation appelle ces méthodes sur le thread qui a créé le gestionnaire, ici le principal.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.update() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        let latitude = coordinate.latitude, longitude = coordinate.longitude
        Task { @MainActor in await self.fetch(latitude: latitude, longitude: longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.errorMessage = "Position indisponible pour le moment." }
    }

    private func fetch(latitude: Double, longitude: Double) async {
        guard let url = WeatherAPI.url(latitude: latitude, longitude: longitude) else { return }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let new = WeatherReport.parse(data)
        else {
            // On garde la dernière météo connue plutôt que de vider l'affichage.
            errorMessage = "Météo indisponible pour le moment."
            return
        }
        guard isRunning else { return }
        report = new
        errorMessage = nil
    }
}
