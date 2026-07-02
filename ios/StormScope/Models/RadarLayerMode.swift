import Foundation

/// Which imagery layers the radar map renders. Persisted between sessions.
nonisolated enum RadarLayerMode: String, CaseIterable, Identifiable {
    case radar
    case satellite
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .radar: return "Radar"
        case .satellite: return "Satellite"
        case .both: return "Both"
        }
    }

    var icon: String {
        switch self {
        case .radar: return "antenna.radiowaves.left.and.right"
        case .satellite: return "cloud.fill"
        case .both: return "square.2.layers.3d.fill"
        }
    }

    /// Whether the animated NEXRAD reflectivity tiles are drawn.
    var showsRadar: Bool { self != .satellite }

    /// Whether the GOES infrared cloud-top tiles are drawn.
    var showsSatellite: Bool { self != .radar }
}
