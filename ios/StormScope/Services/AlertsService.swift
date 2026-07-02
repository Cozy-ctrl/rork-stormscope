import Foundation

nonisolated enum AlertsServiceError: Error {
    case badURL
    case badResponse
    /// api.weather.gov only covers United States territory.
    case outsideCoverage
}

/// Fetches active National Weather Service alerts (free api.weather.gov,
/// no API key) for a coordinate. This is the same official feed weather
/// stations relay, delivered straight to the device.
nonisolated final class AlertsService {
    func fetchActiveAlerts(latitude: Double, longitude: Double) async throws -> [NWSAlertFeature] {
        var components = URLComponents(string: "https://api.weather.gov/alerts/active")
        components?.queryItems = [
            URLQueryItem(name: "point", value: String(format: "%.4f,%.4f", latitude, longitude)),
            URLQueryItem(name: "status", value: "actual"),
            URLQueryItem(name: "message_type", value: "alert"),
        ]
        guard let url = components?.url else { throw AlertsServiceError.badURL }

        var request = URLRequest(url: url)
        // NWS requires an identifying User-Agent on all requests.
        request.setValue("StormScope/1.0 (rork.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AlertsServiceError.badResponse }
        if http.statusCode == 400 {
            // NWS rejects points outside US coverage with a 400 problem document.
            throw AlertsServiceError.outsideCoverage
        }
        guard http.statusCode == 200 else { throw AlertsServiceError.badResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(NWSAlertResponse.self, from: data)
        return payload.features.sorted { lhs, rhs in
            if lhs.isTornadoRelated != rhs.isTornadoRelated { return lhs.isTornadoRelated }
            return lhs.severityRank > rhs.severityRank
        }
    }
}
