import Foundation

/// Health snapshot for the NEXRAD site nearest to the user.
nonisolated struct RadarSiteStatus {
    let id: String
    let name: String
    let isOnline: Bool
    let checkedAt: Date
}

/// Checks whether the nearest NEXRAD radar site is currently scanning, using
/// the Iowa Environmental Mesonet's radar metadata API (free, no key).
/// A site with no volume scans in the last ~45 minutes is treated as offline
/// (maintenance or outage) — the mosaic still renders from neighboring sites.
nonisolated struct RadarStatusService {

    private struct AvailableResponse: Codable {
        struct Radar: Codable {
            let id: String
            let name: String
            let lat: Double
            let lon: Double
            let type: String
        }
        let radars: [Radar]?
    }

    private struct ScanListResponse: Codable {
        struct Scan: Codable {
            let ts: String
        }
        let scans: [Scan]?
    }

    func fetchStatus(latitude: Double, longitude: Double) async -> RadarSiteStatus? {
        guard let nearest = await nearestNEXRAD(latitude: latitude, longitude: longitude) else {
            return nil
        }
        guard let hasRecentScans = await hasRecentScans(radarID: nearest.id) else {
            // Scan lookup failed — don't report a false outage.
            return nil
        }
        return RadarSiteStatus(
            id: nearest.id,
            name: nearest.name,
            isOnline: hasRecentScans,
            checkedAt: Date()
        )
    }

    private func nearestNEXRAD(latitude: Double, longitude: Double) async -> AvailableResponse.Radar? {
        var components = URLComponents(string: "https://mesonet.agron.iastate.edu/json/radar.py")
        components?.queryItems = [
            URLQueryItem(name: "operation", value: "available"),
            URLQueryItem(name: "lat", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", longitude)),
        ]
        guard let url = components?.url else { return nil }

        do {
            let data = try await fetch(url)
            let payload = try JSONDecoder().decode(AvailableResponse.self, from: data)
            let nexrads = (payload.radars ?? []).filter { $0.type == "NEXRAD" }
            return nexrads.min { lhs, rhs in
                squaredDistance(lat: lhs.lat, lon: lhs.lon, toLat: latitude, toLon: longitude)
                    < squaredDistance(lat: rhs.lat, lon: rhs.lon, toLat: latitude, toLon: longitude)
            }
        } catch {
            print("[RadarStatus] Nearest lookup failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Returns true/false when the scan list loads, nil on network failure.
    private func hasRecentScans(radarID: String) async -> Bool? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let now = Date()
        let start = now.addingTimeInterval(-45 * 60)

        var components = URLComponents(string: "https://mesonet.agron.iastate.edu/json/radar.py")
        components?.queryItems = [
            URLQueryItem(name: "operation", value: "list"),
            URLQueryItem(name: "radar", value: radarID),
            URLQueryItem(name: "product", value: "N0B"),
            URLQueryItem(name: "start", value: formatter.string(from: start)),
            URLQueryItem(name: "end", value: formatter.string(from: now)),
        ]
        guard let url = components?.url else { return nil }

        do {
            let data = try await fetch(url)
            let payload = try JSONDecoder().decode(ScanListResponse.self, from: data)
            return !(payload.scans ?? []).isEmpty
        } catch {
            print("[RadarStatus] Scan list failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Rough planar distance — fine for picking the closest of a handful of sites.
    private func squaredDistance(lat: Double, lon: Double, toLat: Double, toLon: Double) -> Double {
        let dLat = lat - toLat
        let dLon = (lon - toLon) * cos(toLat * .pi / 180)
        return dLat * dLat + dLon * dLon
    }
}
