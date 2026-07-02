import Foundation

/// GeoJSON response from api.weather.gov/alerts/active.
nonisolated struct NWSAlertResponse: Codable {
    let features: [NWSAlertFeature]
}

/// A single active National Weather Service alert for the user's location.
nonisolated struct NWSAlertFeature: Codable, Identifiable {
    let id: String
    let properties: NWSAlertProperties
    let geometry: NWSAlertGeometry?
}

/// GeoJSON geometry attached to a warning (Polygon or MultiPolygon).
/// Zone-based alerts (watches, advisories) often have null geometry.
nonisolated struct NWSAlertGeometry: Codable {
    let type: String
    /// Outer ring per polygon; each ring is a list of [longitude, latitude] pairs.
    let outerRings: [[[Double]]]

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        switch type {
        case "Polygon":
            let rings = try container.decode([[[Double]]].self, forKey: .coordinates)
            outerRings = rings.first.map { [$0] } ?? []
        case "MultiPolygon":
            let polygons = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            outerRings = polygons.compactMap { $0.first }
        default:
            outerRings = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
    }
}

nonisolated struct NWSAlertProperties: Codable {
    let event: String
    let headline: String?
    let severity: String?
    let urgency: String?
    let areaDesc: String?
    let instruction: String?
    let ends: Date?
    let expires: Date?
}

nonisolated extension NWSAlertFeature {
    var isTornadoWarning: Bool {
        properties.event.localizedCaseInsensitiveContains("tornado")
            && properties.event.localizedCaseInsensitiveContains("warning")
    }

    var isTornadoWatch: Bool {
        properties.event.localizedCaseInsensitiveContains("tornado")
            && properties.event.localizedCaseInsensitiveContains("watch")
    }

    var isTornadoRelated: Bool {
        properties.event.localizedCaseInsensitiveContains("tornado")
    }

    /// When the alert stops applying, preferring the meteorological end time.
    var endTime: Date? {
        properties.ends ?? properties.expires
    }

    /// Higher rank means more severe; used for sorting the alert list.
    var severityRank: Int {
        switch properties.severity?.lowercased() {
        case "extreme": return 4
        case "severe": return 3
        case "moderate": return 2
        case "minor": return 1
        default: return 0
        }
    }
}
