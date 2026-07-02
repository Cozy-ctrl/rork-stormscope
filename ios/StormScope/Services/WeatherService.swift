import Foundation

/// Fetches hyper-local current conditions from the free Open-Meteo API.
nonisolated struct WeatherService {
    enum WeatherError: LocalizedError {
        case badURL
        case badResponse

        var errorDescription: String? {
            switch self {
            case .badURL: return "Could not build the weather request."
            case .badResponse: return "The weather service returned an error."
            }
        }
    }

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: [
                "temperature_2m",
                "relative_humidity_2m",
                "apparent_temperature",
                "dew_point_2m",
                "weather_code",
                "wind_speed_10m",
                "wind_gusts_10m",
                "wind_direction_10m",
                "precipitation",
                "surface_pressure",
                "cloud_cover",
                "visibility",
            ].joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "precipitation_probability,precipitation,cape,lifted_index"),
            URLQueryItem(name: "forecast_hours", value: "6"),
            // Pull the preceding 24 hours too so we can compute storm-total
            // precipitation. Hourly arrays are ordered oldest-first, so the
            // first 24 entries are the past and the last 6 are the forecast.
            URLQueryItem(name: "past_hours", value: "24"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { throw WeatherError.badURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        // With past_hours=24 the arrays include history — instability and rain
        // probability must consider only the trailing forecast hours.
        let forecastHours = 6
        let rainChance = decoded.hourly?.precipitationProbability?.suffix(forecastHours).max()
        let capeMax = decoded.hourly?.cape?.suffix(forecastHours).max()
        // Most negative Lifted Index over the next 6 hours = most unstable.
        let liftedIndexMin = decoded.hourly?.liftedIndex?.suffix(forecastHours).compactMap { $0 }.min()
        // Storm total: sum of the past 24 hourly precipitation values.
        let precip24h: Double? = decoded.hourly?.precipitation.map { values in
            values.dropLast(forecastHours).reduce(0, +)
        }

        return WeatherSnapshot(
            temperature: decoded.current.temperature2m,
            apparentTemperature: decoded.current.apparentTemperature,
            humidity: decoded.current.relativeHumidity2m,
            windSpeed: decoded.current.windSpeed10m,
            windGust: decoded.current.windGusts10m,
            windDirection: decoded.current.windDirection10m,
            precipitationNow: decoded.current.precipitation,
            precipitationLast24h: precip24h,
            dewPoint: decoded.current.dewPoint2m,
            cloudCover: decoded.current.cloudCover,
            visibility: decoded.current.visibility,
            cape: capeMax,
            liftedIndex: liftedIndexMin,
            stationPressure: decoded.current.surfacePressure,
            weatherCode: decoded.current.weatherCode,
            maxRainChance: rainChance,
            fetchedAt: Date()
        )
    }
}
