import Foundation
import CoreLocation

/// Resolves the user's coarse location and a human-readable place name.
/// Falls back to a default city if permission is denied or no fix arrives.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    /// GPS-derived absolute altitude in meters above sea level.
    /// Used by PressureCalculator to convert station pressure to MSLP.
    private(set) var altitude: Double?
    private(set) var placeName: String?
    private(set) var isFallback = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    /// Stable identity for `.task(id:)` so weather refetches on location change.
    var coordinateKey: String {
        guard let latitude, let longitude else { return "none" }
        return String(format: "%.3f,%.3f", latitude, longitude)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            applyFallback()
        }
    }

    /// Enables significant-location-change monitoring so iOS relaunches the
    /// app in the background, letting the barometer catch up and thresholds
    /// be re-checked without the app being open.
    func setBackgroundMonitoring(_ enabled: Bool) {
        if enabled {
            if manager.authorizationStatus == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }
            manager.startMonitoringSignificantLocationChanges()
        } else {
            manager.stopMonitoringSignificantLocationChanges()
        }
    }

    /// Used after a timeout when no GPS fix has arrived (common in simulators).
    func applyFallbackIfNeeded() {
        guard latitude == nil else { return }
        applyFallback()
    }

    private func applyFallback() {
        isFallback = true
        latitude = 37.7749
        longitude = -122.4194
        placeName = "San Francisco"
    }

    private func handleLocation(latitude lat: Double, longitude lon: Double, altitude alt: Double) {
        isFallback = false
        latitude = lat
        longitude = lon
        altitude = alt
        // Persist for background task use so alerts can be fetched
        // for the correct location even when the app is closed.
        UserDefaults.standard.set(lat, forKey: "stormscope.location.lat")
        UserDefaults.standard.set(lon, forKey: "stormscope.location.lon")
        UserDefaults.standard.set(alt, forKey: "stormscope.location.alt")
        reverseGeocode(latitude: lat, longitude: lon)
    }

    private func reverseGeocode(latitude lat: Double, longitude lon: Double) {
        let location = CLLocation(latitude: lat, longitude: lon)
        Task { [weak self] in
            guard let self else { return }
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let mark = placemarks.first {
                    self.placeName = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea
                }
            } catch {
                print("[Location] Reverse geocode failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                self.applyFallback()
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude
        let lon = last.coordinate.longitude
        let alt = last.altitude
        Task { @MainActor in
            self.handleLocation(latitude: lat, longitude: lon, altitude: alt)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] Failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.applyFallbackIfNeeded()
        }
    }
}
