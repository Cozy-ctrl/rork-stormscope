import Foundation

/// A detected electromagnetic spike in the magnetometer stream consistent
/// with a nearby lightning discharge.
///
/// Distance estimation is coarse — it's based on the inverse-square falloff
/// of the EMP: a 1 µT spike at 10 km, 10 µT at 1 km, 100 µT at 100 m.
/// Real values vary with strike current and path, so treat this as an
/// approximate guide, not a precise measurement.
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
        // Rough inverse-square: at 1 km a typical close cloud-to-ground
        // strike produces ~10 µT above ambient. Scale accordingly.
        let reference = max(peakDeviation, 0.5)
        return 10.0 / sqrt(reference / 10.0)
    }

    /// Human-readable distance bucket.
    var proximity: StrikeProximity {
        let d = estimatedDistanceKm
        if d <= 1.0  { return .veryClose }
        if d <= 5.0  { return .nearby }
        if d <= 20.0 { return .distant }
        return .far
    }
}

/// Bucketed proximity estimate for a detected magnetic spike.
nonisolated enum StrikeProximity: String, CaseIterable {
    case none       = "None"
    case veryClose  = "Very Close (<1 km)"
    case nearby     = "Nearby (1–5 km)"
    case distant    = "Distant (5–20 km)"
    case far        = "Far (>20 km)"

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
