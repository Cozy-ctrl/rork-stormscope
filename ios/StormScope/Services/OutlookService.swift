import Foundation

nonisolated enum OutlookServiceError: Error {
    case badURL
    case badResponse
}

/// Queries the Storm Prediction Center's convective outlook layers
/// (mapservices.weather.noaa.gov, free, no key) for a point: categorical
/// risk plus tornado/hail/wind probabilities for Days 1–3.
nonisolated final class OutlookService {

    private struct QueryResponse: Codable {
        struct Feature: Codable {
            struct Attributes: Codable {
                let dn: Int?
            }
            let attributes: Attributes
        }
        let features: [Feature]?
    }

    /// SPC_wx_outlks MapServer layer ids.
    private enum Layer {
        static let day1Categorical = 1
        static let day1Tornado = 3
        static let day1Hail = 5
        static let day1Wind = 7
        static let day2Categorical = 9
        static let day2Tornado = 11
        static let day2Hail = 13
        static let day2Wind = 15
        static let day3Categorical = 17
        static let day3Severe = 18
    }

    func fetchOutlooks(latitude: Double, longitude: Double) async -> [SPCOutlook] {
        async let day1 = fetchDay(
            1, latitude: latitude, longitude: longitude,
            categorical: Layer.day1Categorical,
            tornado: Layer.day1Tornado, hail: Layer.day1Hail, wind: Layer.day1Wind
        )
        async let day2 = fetchDay(
            2, latitude: latitude, longitude: longitude,
            categorical: Layer.day2Categorical,
            tornado: Layer.day2Tornado, hail: Layer.day2Hail, wind: Layer.day2Wind
        )
        async let day3 = fetchDay(
            3, latitude: latitude, longitude: longitude,
            categorical: Layer.day3Categorical,
            severe: Layer.day3Severe
        )
        return await [day1, day2, day3]
    }

    private func fetchDay(
        _ day: Int,
        latitude: Double,
        longitude: Double,
        categorical: Int,
        tornado: Int? = nil,
        hail: Int? = nil,
        wind: Int? = nil,
        severe: Int? = nil
    ) async -> SPCOutlook {
        async let category = maxDN(layer: categorical, latitude: latitude, longitude: longitude)
        async let tornadoProb = optionalMaxDN(layer: tornado, latitude: latitude, longitude: longitude)
        async let hailProb = optionalMaxDN(layer: hail, latitude: latitude, longitude: longitude)
        async let windProb = optionalMaxDN(layer: wind, latitude: latitude, longitude: longitude)
        async let severeProb = optionalMaxDN(layer: severe, latitude: latitude, longitude: longitude)

        return await SPCOutlook(
            day: day,
            categoryCode: category,
            tornadoProbability: tornadoProb,
            hailProbability: hailProb,
            windProbability: windProb,
            severeProbability: severeProb
        )
    }

    private func optionalMaxDN(layer: Int?, latitude: Double, longitude: Double) async -> Int? {
        guard let layer else { return nil }
        return await maxDN(layer: layer, latitude: latitude, longitude: longitude)
    }

    /// Point-in-polygon query returning the highest `dn` value that covers
    /// the coordinate, or nil when no outlook polygon applies (or on error —
    /// the outlook card degrades gracefully).
    private func maxDN(layer: Int, latitude: Double, longitude: Double) async -> Int? {
        var components = URLComponents(
            string: "https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/MapServer/\(layer)/query"
        )
        components?.queryItems = [
            URLQueryItem(name: "geometry", value: String(format: "%.4f,%.4f", longitude, latitude)),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "dn"),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "f", value: "json"),
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let payload = try JSONDecoder().decode(QueryResponse.self, from: data)
            let values = (payload.features ?? []).compactMap { $0.attributes.dn }
            return values.max()
        } catch {
            print("[Outlook] Layer \(layer) query failed: \(error.localizedDescription)")
            return nil
        }
    }
}
