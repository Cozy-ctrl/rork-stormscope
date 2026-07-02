import Foundation
import CoreLocation

/// The latest real measured observation from a nearby NWS station.
nonisolated struct StationObservation: Identifiable {
    /// Station identifier, e.g. "KSFO".
    let id: String
    let name: String
    /// WGS84 latitude of the station.
    let latitude: Double
    /// WGS84 longitude of the station.
    let longitude: Double
    /// Great-circle distance from the user's position, in kilometers.
    let distanceKm: Double
    /// Measured sea-level (preferred) or station barometric pressure, in hPa.
    let pressureHPa: Double?
    /// Measured air temperature, in Celsius.
    let temperatureC: Double?
    /// Dew point, in Celsius — higher values mean more moisture available for storms.
    let dewPointC: Double?
    /// Wind speed, in km/h.
    let windSpeedKmh: Double?
    /// Wind gust, in km/h.
    let windGustKmh: Double?
    /// Wind direction, in degrees (0 = north, 90 = east).
    let windDirectionDeg: Double?
    /// Relative humidity, percentage.
    let humidity: Int?
    /// Horizontal visibility, in meters.
    let visibilityM: Double?
    /// Precipitation in the last hour, in mm.
    let precipLastHourMm: Double?
    let conditions: String?
    let observedAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
