import CoreLocation
import Foundation
import WeatherKit

enum NativeWeatherAccessStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unavailable

    var canRequestWeather: Bool {
        self == .authorized
    }

    init(_ authorizationStatus: CLAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorizedAlways, .authorizedWhenInUse:
            self = .authorized
        @unknown default:
            self = .unavailable
        }
    }
}

struct NativeWeatherSnapshot: Sendable, Equatable {
    var temperature: Int
    var feelsLike: Int
    var high: Int?
    var low: Int?
    var precipitationChance: Int?
    var condition: String
    var symbolName: String
    var updatedAt: Date
}

@MainActor
final class NativeWeatherService: NSObject, ObservableObject {
    @Published private(set) var accessStatus: NativeWeatherAccessStatus = .notDetermined
    @Published private(set) var snapshot: NativeWeatherSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?
    private var initialStatusContinuation: CheckedContinuation<Void, Never>?
    private var didPrepareLocationManager = false
    private var didReceiveAuthorizationUpdate = false
    private lazy var isWeatherKitEnabled = Self.currentBuildAllowsWeatherKitRequests()
    private var lastRefreshAttemptAt: Date?

    private let automaticRefreshBackoff: TimeInterval = 15 * 60

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return manager
    }()

    func activateIfAuthorized() async {
        await waitForInitialAuthorizationStatus()
        guard accessStatus.canRequestWeather else { return }
        await refreshWeather()
    }

    func requestAccessAndRefresh() async {
        await waitForInitialAuthorizationStatus()
        if accessStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        }
        await refreshWeather(force: true)
    }

    func refreshWeather(force: Bool = false) async {
        guard didPrepareLocationManager, accessStatus.canRequestWeather else { return }
        guard force || shouldRefreshAutomatically else { return }

        isLoading = true
        errorMessage = nil
        lastRefreshAttemptAt = .now
        defer { isLoading = false }

        do {
            let location = try await requestCurrentLocation()
            snapshot = try await Task.detached(priority: .userInitiated) {
                let weather = try await WeatherService.shared.weather(for: location)
                return NativeWeatherSnapshot(weather: weather)
            }.value
        } catch {
            errorMessage = NativeWeatherError.userFacingMessage(for: error)
        }
    }

    private var shouldRefreshAutomatically: Bool {
        guard !isLoading else { return false }
        guard snapshot == nil else { return true }
        guard let lastRefreshAttemptAt else { return true }
        return Date().timeIntervalSince(lastRefreshAttemptAt) >= automaticRefreshBackoff
    }

    private func waitForInitialAuthorizationStatus() async {
        prepareLocationManagerIfNeeded()
        guard !didReceiveAuthorizationUpdate else { return }
        await withCheckedContinuation { continuation in
            initialStatusContinuation = continuation
        }
    }

    private func prepareLocationManagerIfNeeded() {
        guard !didPrepareLocationManager else { return }
        didPrepareLocationManager = true
        guard isWeatherKitEnabled else {
            accessStatus = .unavailable
            errorMessage = "Weather is unavailable until WeatherKit is enabled for this app."
            didReceiveAuthorizationUpdate = true
            #if DEBUG
            // WeatherKit can't be provisioned on a Personal team, so debug builds show a sample
            // reading to let the header readout be designed and checked. Release builds never
            // do: with WeatherKit off they show nothing rather than invented weather.
            snapshot = .sample
            #endif
            return
        }
        locationManager.delegate = self
    }

    private func requestCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation?.resume(throwing: NativeWeatherError.locationRequestReplaced)
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    nonisolated private static func currentBuildAllowsWeatherKitRequests() -> Bool {
        Bundle.main.object(forInfoDictionaryKey: "BEACON_WEATHERKIT_ENABLED") as? Bool == true
    }
}

extension NativeWeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = NativeWeatherAccessStatus(manager.authorizationStatus)
        Task { @MainActor in
            accessStatus = status
            didReceiveAuthorizationUpdate = true
            if let initialStatusContinuation {
                self.initialStatusContinuation = nil
                initialStatusContinuation.resume()
            }
            guard status != .notDetermined, let authorizationContinuation else { return }
            self.authorizationContinuation = nil
            authorizationContinuation.resume()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                locationContinuation?.resume(throwing: NativeWeatherError.locationUnavailable)
                locationContinuation = nil
                return
            }
            locationContinuation?.resume(returning: location)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(throwing: error)
            locationContinuation = nil
        }
    }
}

#if DEBUG
extension NativeWeatherSnapshot {
    /// Placeholder reading for debug builds while WeatherKit is unavailable.
    static let sample = NativeWeatherSnapshot(
        temperature: 78,
        feelsLike: 80,
        high: 85,
        low: 66,
        precipitationChance: 20,
        condition: "Partly Cloudy",
        symbolName: "cloud.sun.fill",
        updatedAt: .now
    )
}
#endif

extension NativeWeatherSnapshot {
    fileprivate init(weather: Weather) {
        let current = weather.currentWeather
        let today = weather.dailyForecast.forecast.first

        self.init(
            temperature: Self.fahrenheit(current.temperature),
            feelsLike: Self.fahrenheit(current.apparentTemperature),
            high: today.map { Self.fahrenheit($0.highTemperature) },
            low: today.map { Self.fahrenheit($0.lowTemperature) },
            precipitationChance: today.map { Int(($0.precipitationChance * 100).rounded()) },
            condition: current.condition.description,
            symbolName: current.symbolName,
            updatedAt: .now
        )
    }

    private static func fahrenheit(_ measurement: Measurement<UnitTemperature>) -> Int {
        Int(measurement.converted(to: .fahrenheit).value.rounded())
    }
}

private enum NativeWeatherError: LocalizedError {
    case locationUnavailable
    case locationRequestReplaced

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            "Could not find this device's location."
        case .locationRequestReplaced:
            "A newer weather request started."
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("weatherkit")
            || description.localizedCaseInsensitiveContains("weather")
            || description.localizedCaseInsensitiveContains("authservice")
            || description.localizedCaseInsensitiveContains("not entitled") {
            return "Weather is unavailable until WeatherKit is enabled for this app."
        }
        return description
    }
}
