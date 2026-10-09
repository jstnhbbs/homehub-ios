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
    var humidity: Int?
    var windSpeed: Int?
    var uvIndex: Int?
    var updatedAt: Date
    /// The debug placeholder shown while WeatherKit is off, so the details panel can say so instead
    /// of crediting Apple Weather for invented numbers.
    var isSample = false
}

/// What Apple requires next to WeatherKit data: its Apple Weather mark (one for light and one for
/// dark backgrounds) and a link to the page that lists the other data sources.
struct WeatherAttributionInfo: Sendable, Equatable {
    var lightMarkURL: URL
    var darkMarkURL: URL
    var legalPageURL: URL
    var serviceName: String
}

@MainActor
final class NativeWeatherService: NSObject, ObservableObject {
    @Published private(set) var accessStatus: NativeWeatherAccessStatus = .notDetermined
    @Published private(set) var snapshot: NativeWeatherSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var attribution: WeatherAttributionInfo?

    private let locationWaiters = AsyncCallbackWaiters<CLLocation>()
    private let authorizationWaiters = AsyncCallbackWaiters<Void>()
    private let initialStatusWaiters = AsyncCallbackWaiters<Void>()
    private var didPrepareLocationManager = false
    private var didReceiveAuthorizationUpdate = false
    private lazy var isWeatherKitEnabled = Self.currentBuildAllowsWeatherKitRequests()
    private var lastRefreshAttemptAt: Date?

    /// A reading is reused for this long. The temperature on a dashboard doesn't change meaningfully
    /// faster, and every fetch is a WeatherKit call. Pull to refresh asks regardless.
    private let automaticRefreshBackoff: TimeInterval = 60 * 60
    /// After a failed attempt with nothing to show, try again sooner than a good reading would be.
    private let retryBackoff: TimeInterval = 15 * 60

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return manager
    }()

    func activateIfAuthorized() async {
        do {
            try await waitForInitialAuthorizationStatus()
            guard accessStatus.canRequestWeather else { return }
            await refreshWeather()
        } catch {
            if !error.isCancellation { errorMessage = NativeWeatherError.userFacingMessage(for: error) }
        }
    }

    func requestAccessAndRefresh() async {
        do {
            try await waitForInitialAuthorizationStatus()
            if accessStatus == .notDetermined {
                try await authorizationWaiters.wait(timeout: .seconds(120), timeoutError: NativeWeatherError.requestTimedOut) {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
            await refreshWeather(force: true)
        } catch {
            if !error.isCancellation { errorMessage = NativeWeatherError.userFacingMessage(for: error) }
        }
    }

    func refreshWeather(force: Bool = false) async {
        guard didPrepareLocationManager, accessStatus.canRequestWeather else { return }
        guard !isLoading, !Task.isCancelled else { return }
        guard force || shouldRefreshAutomatically else { return }

        isLoading = true
        errorMessage = nil
        lastRefreshAttemptAt = .now
        defer { isLoading = false }

        do {
            let location = try await requestCurrentLocation()
            let weather = try await WeatherService.shared.weather(for: location)
            try Task.checkCancellation()
            snapshot = NativeWeatherSnapshot(weather: weather)
            // Fetched once; it only changes with the service itself.
            if attribution == nil, let info = try? await WeatherService.shared.attribution {
                attribution = WeatherAttributionInfo(
                    lightMarkURL: info.combinedMarkLightURL,
                    darkMarkURL: info.combinedMarkDarkURL,
                    legalPageURL: info.legalPageURL,
                    serviceName: info.serviceName
                )
            }
        } catch {
            if !error.isCancellation {
                // The reason (never the location), so a WeatherKit setup problem can be told apart
                // from a location or network one.
                NSLog("Porchlight: weather request failed: %@", String(describing: error))
                errorMessage = NativeWeatherError.userFacingMessage(for: error)
            }
        }
    }

    private var shouldRefreshAutomatically: Bool {
        guard !isLoading else { return false }
        // Every dashboard refresh asks, and each check-off triggers one, so a reading that is
        // still recent must be reused rather than fetched again.
        if let snapshot {
            return Date().timeIntervalSince(snapshot.updatedAt) >= automaticRefreshBackoff
        }
        guard let lastRefreshAttemptAt else { return true }
        return Date().timeIntervalSince(lastRefreshAttemptAt) >= retryBackoff
    }

    private func waitForInitialAuthorizationStatus() async throws {
        prepareLocationManagerIfNeeded()
        guard !didReceiveAuthorizationUpdate else { return }
        try await initialStatusWaiters.wait(timeout: .seconds(10), timeoutError: NativeWeatherError.requestTimedOut)
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
        try await locationWaiters.wait(timeout: .seconds(15), timeoutError: NativeWeatherError.requestTimedOut) {
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
            initialStatusWaiters.resolve(.success(()))
            if !status.canRequestWeather, status != .notDetermined {
                locationWaiters.resolve(.failure(NativeWeatherError.locationUnavailable))
            }
            guard status != .notDetermined else { return }
            authorizationWaiters.resolve(.success(()))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                locationWaiters.resolve(.failure(NativeWeatherError.locationUnavailable))
                return
            }
            locationWaiters.resolve(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationWaiters.resolve(.failure(error))
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
        humidity: 48,
        windSpeed: 8,
        uvIndex: 5,
        updatedAt: .now,
        isSample: true
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
            humidity: Int((current.humidity * 100).rounded()),
            windSpeed: Int(current.wind.speed.converted(to: .milesPerHour).value.rounded()),
            uvIndex: current.uvIndex.value,
            updatedAt: .now
        )
    }

    private static func fahrenheit(_ measurement: Measurement<UnitTemperature>) -> Int {
        Int(measurement.converted(to: .fahrenheit).value.rounded())
    }
}

private enum NativeWeatherError: LocalizedError {
    case locationUnavailable
    case requestTimedOut

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            "Could not find this device's location."
        case .requestTimedOut:
            "The location request took too long. Try again."
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
