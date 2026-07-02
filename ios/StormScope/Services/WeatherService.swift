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
                "surface_pressure",
                "cloud_cover",
                "visibility",
            ].joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "precipitation_probability,cape"),
            URLQueryItem(name: "forecast_hours", value: "6"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components?.url else { throw WeatherError.badURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        let rainChance = decoded.hourly?.precipitationProbability?.max()
        let capeMax = decoded.hourly?.cape?.max()

        return WeatherSnapshot(
            temperature: decoded.current.temperature2m,
            apparentTemperature: decoded.current.apparentTemperature,
            humidity: decoded.current.relativeHumidity2m,
            windSpeed: decoded.current.windSpeed10m,
            windGust: decoded.current.windGusts10m,
            dewPoint: decoded.current.dewPoint2m,
            cloudCover: decoded.current.cloudCover,
            visibility: decoded.current.visibility,
            cape: capeMax,
            stationPressure: decoded.current.surfacePressure,
            weatherCode: decoded.current.weatherCode,
            maxRainChance: rainChance,
            fetchedAt: Date()
        )
    }
}
