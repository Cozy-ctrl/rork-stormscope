import Foundation
import CoreLocation

nonisolated enum StationsServiceError: Error {
    case badURL
    case badResponse
    /// api.weather.gov only covers United States territory.
    case outsideCoverage
}

/// Discovers the nearest NWS observation stations for a coordinate and pulls
/// each station's latest real measured readings (free api.weather.gov, no key).
///
/// Flow: `/points/{lat},{lon}` → grid's observation-station list (ordered by
/// proximity) → `/stations/{id}/observations/latest` per station.
///
/// Pulls pressure, temperature, dew point, wind speed/gusts/direction, humidity,
/// visibility, and precipitation so the dashboard cross-references every
/// instrument the station records.
nonisolated final class StationsService {

    // MARK: - Wire models

    private struct PointsResponse: Codable {
        struct Properties: Codable {
            let observationStations: String
        }
        let properties: Properties
    }

    private struct StationsResponse: Codable {
        struct Feature: Codable {
            struct Properties: Codable {
                let stationIdentifier: String
                let name: String
            }
            struct Geometry: Codable {
                /// GeoJSON order: [longitude, latitude].
                let coordinates: [Double]
            }
            let properties: Properties
            let geometry: Geometry
        }
        let features: [Feature]
    }

    private struct ObservationResponse: Codable {
        struct Measurement: Codable {
            let value: Double?
        }
        struct Properties: Codable {
            let timestamp: Date?
            let textDescription: String?
            let temperature: Measurement?
            let seaLevelPressure: Measurement?
            let barometricPressure: Measurement?
            let dewpoint: Measurement?
            let windSpeed: Measurement?
            let windGust: Measurement?
            let windDirection: Measurement?
            let relativeHumidity: Measurement?
            let visibility: Measurement?
            let precipitationLastHour: Measurement?
        }
        let properties: Properties
    }

    private struct ObservationHistoryResponse: Codable {
        struct Feature: Codable {
            let properties: ObservationResponse.Properties
        }
        let features: [Feature]
    }

    // MARK: - API

    func fetchNearbyObservations(
        latitude: Double,
        longitude: Double,
        limit: Int = 8
    ) async throws -> [StationObservation] {
        let pointsURLString = String(format: "https://api.weather.gov/points/%.4f,%.4f", latitude, longitude)
        guard let pointsURL = URL(string: pointsURLString) else { throw StationsServiceError.badURL }

        let points: PointsResponse = try await fetch(pointsURL)
        guard let stationsURL = URL(string: points.properties.observationStations) else {
            throw StationsServiceError.badURL
        }

        let stationList: StationsResponse = try await fetch(stationsURL)
        let nearest = Array(stationList.features.prefix(limit))
        guard !nearest.isEmpty else { return [] }

        let userLocation = CLLocation(latitude: latitude, longitude: longitude)

        var results: [StationObservation] = []
        try await withThrowingTaskGroup(of: StationObservation?.self) { group in
            for feature in nearest {
                group.addTask { [weak self] in
                    await self?.latestObservation(for: feature, userLocation: userLocation)
                }
            }
            for try await observation in group {
                if let observation {
                    results.append(observation)
                }
            }
        }
        return results.sorted { $0.distanceKm < $1.distanceKm }
    }

    /// Pulls each station's recent observation history and computes an
    /// hour-over-hour pressure delta. Used during extreme-event rapid polling
    /// to confirm a device-detected pressure crash against official sensors.
    /// ASOS stations issue special (SPECI) reports during rapid pressure
    /// changes, so re-polling every few minutes catches them early.
    func fetchPressureTrends(
        for stations: [StationObservation],
        maxStations: Int = 5
    ) async -> [StationPressureTrend] {
        let picks = Array(stations.prefix(maxStations))
        guard !picks.isEmpty else { return [] }

        var results: [StationPressureTrend] = []
        await withTaskGroup(of: StationPressureTrend?.self) { group in
            for station in picks {
                group.addTask { [weak self] in
                    await self?.pressureTrend(for: station)
                }
            }
            for await trend in group {
                if let trend {
                    results.append(trend)
                }
            }
        }
        return results.sorted { $0.distanceKm < $1.distanceKm }
    }

    // MARK: - Helpers

    /// Fetches ~2.5 hours of observations for one station and computes the
    /// pressure change over the last hour (nil when the station hasn't
    /// reported enough points). Returns nil on network failure so one dead
    /// station never fails the confirmation check.
    private func pressureTrend(for station: StationObservation) async -> StationPressureTrend? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.string(from: Date().addingTimeInterval(-2.5 * 3600))
        guard let url = URL(string: "https://api.weather.gov/stations/\(station.id)/observations?start=\(start)") else {
            return nil
        }

        do {
            let history: ObservationHistoryResponse = try await fetch(url)
            var samples: [(timestamp: Date, hPa: Double)] = []
            for feature in history.features {
                let properties = feature.properties
                guard let timestamp = properties.timestamp,
                      let pressurePa = properties.seaLevelPressure?.value ?? properties.barometricPressure?.value else {
                    continue
                }
                samples.append((timestamp, pressurePa / 100.0))
            }
            samples.sort { $0.timestamp < $1.timestamp }
            guard let latest = samples.last else { return nil }

            // Anchor: the observation closest to one hour before the latest
            // report, within a 45-minute tolerance (stations report ~hourly).
            let target = latest.timestamp.addingTimeInterval(-3600)
            let anchor = samples.min {
                abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target))
            }
            var delta: Double?
            if let anchor,
               anchor.timestamp < latest.timestamp,
               abs(anchor.timestamp.timeIntervalSince(target)) <= 2700 {
                delta = latest.hPa - anchor.hPa
            }

            return StationPressureTrend(
                id: station.id,
                name: station.name,
                distanceKm: station.distanceKm,
                latestHPa: latest.hPa,
                deltaHPa: delta,
                observedAt: latest.timestamp
            )
        } catch {
            print("[Stations] \(station.id) trend history unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches a single station's latest observation; returns nil if the
    /// station has no recent report so one dead station doesn't fail the card.
    private func latestObservation(
        for feature: StationsResponse.Feature,
        userLocation: CLLocation
    ) async -> StationObservation? {
        let stationId = feature.properties.stationIdentifier
        guard let url = URL(string: "https://api.weather.gov/stations/\(stationId)/observations/latest") else {
            return nil
        }

        let coordinates = feature.geometry.coordinates
        var stationLat = 0.0
        var stationLon = 0.0
        var distanceKm = 0.0
        if coordinates.count >= 2 {
            stationLat = coordinates[1]
            stationLon = coordinates[0]
            let stationLocation = CLLocation(latitude: stationLat, longitude: stationLon)
            distanceKm = userLocation.distance(from: stationLocation) / 1000.0
        }

        do {
            let observation: ObservationResponse = try await fetch(url)
            let properties = observation.properties
            let pressurePa = properties.seaLevelPressure?.value ?? properties.barometricPressure?.value

            // NWS reports wind speed in m/s; convert to km/h.
            let windMs = properties.windSpeed?.value
            let gustMs = properties.windGust?.value

            // Visibility is reported in meters.
            let visM = properties.visibility?.value

            // Precipitation last hour is reported in mm (as kg/m² which is equivalent to mm).
            let precipMm = properties.precipitationLastHour?.value

            return StationObservation(
                id: stationId,
                name: feature.properties.name,
                latitude: stationLat,
                longitude: stationLon,
                distanceKm: distanceKm,
                pressureHPa: pressurePa.map { $0 / 100.0 },
                temperatureC: properties.temperature?.value,
                dewPointC: properties.dewpoint?.value,
                windSpeedKmh: windMs.map { $0 * 3.6 },
                windGustKmh: gustMs.map { $0 * 3.6 },
                windDirectionDeg: properties.windDirection?.value,
                humidity: properties.relativeHumidity?.value.map { Int($0) },
                visibilityM: visM,
                precipLastHourMm: precipMm,
                conditions: properties.textDescription?.isEmpty == false ? properties.textDescription : nil,
                observedAt: properties.timestamp
            )
        } catch {
            print("[Stations] \(stationId) latest observation unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        // NWS requires an identifying User-Agent on all requests.
        request.setValue("StormScope/1.0 (rork.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StationsServiceError.badResponse }
        if http.statusCode == 400 || http.statusCode == 404 {
            // NWS rejects points outside US coverage.
            throw StationsServiceError.outsideCoverage
        }
        guard http.statusCode == 200 else { throw StationsServiceError.badResponse }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
