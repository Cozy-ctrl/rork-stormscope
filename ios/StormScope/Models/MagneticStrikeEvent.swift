import Foundation

/// A detected electromagnetic spike in the magnetometer stream consistent
/// with a nearby lightning discharge.
///
/// Distance estimation is coarse. A strong cloud-to-ground strike produces
/// a magnetic pulse of very roughly 30 µT·km — about 30 µT at 1 km, falling
/// to ~3 µT at 10 km. Because the detector requires an 8 µT deviation to
/// register at all (movement rejection), only close-range strikes (within
/// a few km) are detectable, and the proximity buckets reflect that. Real
/// values vary with strike current and path — treat this as an approximate
/// guide, not a precise measurement.
nonisolated struct MagneticStrikeEvent {
    /// When the spike was detected.
    let timestamp: Date

    /// The total magnetic field magnitude at the peak of the spike (µT).
    let totalField: Double

    /// The rolling baseline ambient field just before the spike (µT).
    let baseline: Double

    /// The maximum deviation above baseline recorded for this event (µT).
    let peakDeviation: Double

    /// Coarse distance estimate based on EMP signal strength, in km.
    var estimatedDistanceKm: Double {
        // Inverse falloff anchored at ~30 µT·km for a strong strike.
        // Clamped to the detector's usable range: the 8 µT floor means
        // anything registered is within a few kilometers.
        let reference = max(peakDeviation, 1.0)
        return min(max(30.0 / reference, 0.2), 10.0)
    }

    /// Human-readable distance bucket, scaled to the detector's actual
    /// reach (the 8 µT floor caps estimates near ~4 km).
    var proximity: StrikeProximity {
        let d = estimatedDistanceKm
        if d <= 1.0 { return .veryClose }
        if d <= 2.0 { return .nearby }
        if d <= 4.0 { return .distant }
        return .far
    }
}

/// Bucketed proximity estimate for a detected magnetic spike.
nonisolated enum StrikeProximity: String, CaseIterable {
    case none       = "None"
    case veryClose  = "Very Close (<1 km)"
    case nearby     = "Nearby (1–2 km)"
    case distant    = "Distant (2–4 km)"
    case far        = "Far (>4 km)"

    var tint: String {
        switch self {
        case .none:      return "secondary"
        case .veryClose: return "red"
        case .nearby:    return "orange"
        case .distant:   return "amber"
        case .far:       return "green"
        }
    }
}
