import Foundation

/// Display-ready localized weather conditions for the user's position.
nonisolated struct WeatherSnapshot {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    /// Maximum wind gust over the current period, in km/h.
    let windGust: Double?
    /// Dew point temperature, in Celsius — critical for storm potential assessment.
    let dewPoint: Double?
    /// Total cloud cover percentage (0–100).
    let cloudCover: Int?
    /// Horizontal visibility, in meters.
    let visibility: Double?
    /// Convective Available Potential Energy (J/kg) — the primary metric for
    /// severe thunderstorm potential. Values above 1000 indicate moderate
    /// instability; above 2500 extreme.
    let cape: Double?
    /// Station-level surface pressure reported by the nearest weather model, in hPa.
    let stationPressure: Double
    let weatherCode: Int
    /// Highest precipitation probability over the next six hours, if available.
    let maxRainChance: Int?
    let fetchedAt: Date
}
