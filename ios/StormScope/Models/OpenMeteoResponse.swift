import Foundation

/// Raw DTO for the Open-Meteo forecast API response.
nonisolated struct OpenMeteoResponse: Codable {
    let current: Current
    let hourly: Hourly?

    nonisolated struct Current: Codable {
        let temperature2m: Double
        let relativeHumidity2m: Int
        let apparentTemperature: Double
        let dewPoint2m: Double?
        let weatherCode: Int
        let windSpeed10m: Double
        let windGusts10m: Double?
        let windDirection10m: Double?
        let precipitation: Double?
        let surfacePressure: Double
        let cloudCover: Int?
        let visibility: Double?

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case dewPoint2m = "dew_point_2m"
            case weatherCode = "weather_code"
            case windSpeed10m = "wind_speed_10m"
            case windGusts10m = "wind_gusts_10m"
            case windDirection10m = "wind_direction_10m"
            case precipitation
            case surfacePressure = "surface_pressure"
            case cloudCover = "cloud_cover"
            case visibility
        }
    }

    nonisolated struct Hourly: Codable {
        let precipitationProbability: [Int]?
        /// Hourly precipitation totals in mm; includes past hours when
        /// `past_hours` is requested.
        let precipitation: [Double]?
        let cape: [Double]?
        /// Element type is optional because Open-Meteo returns null for hours
        /// where the stability model has no value.
        let liftedIndex: [Double?]?

        enum CodingKeys: String, CodingKey {
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case cape
            case liftedIndex = "lifted_index"
        }
    }
}
