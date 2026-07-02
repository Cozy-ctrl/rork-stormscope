import Foundation

/// Independent pressure-unit preference so the user can pick hPa, inHg,
/// mmHg, or a dual hPa + inHg readout — regardless of the metric / imperial
/// setting used for temperature, wind, and distance.
nonisolated enum PressureDisplayMode: String, CaseIterable, Identifiable {
    case hPa
    case inHg
    case mmHg
    case dual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hPa:  return "hPa"
        case .inHg: return "inHg"
        case .mmHg: return "mmHg"
        case .dual: return "Dual (hPa + inHg)"
        }
    }

    /// Label for the MSLP badge shown next to pressure readouts.
    var mslpLabel: String {
        switch self {
        case .hPa:  return "MSLP hPa"
        case .inHg: return "MSLP inHg"
        case .mmHg: return "MSLP mmHg"
        case .dual: return "MSLP hPa"
        }
    }

    var summary: String {
        switch self {
        case .hPa:  return "hectopascals (meteorological standard)"
        case .inHg: return "inches of mercury (U.S. standard)"
        case .mmHg: return "millimeters of mercury (medical / legacy)"
        case .dual: return "show both hPa and inHg at a glance"
        }
    }

    var primaryUnit: String {
        switch self {
        case .hPa:  return "hPa"
        case .inHg: return "inHg"
        case .mmHg: return "mmHg"
        case .dual: return "hPa"
        }
    }

    /// Converts an hPa value into the selected unit's numeric value.
    func value(_ hPa: Double) -> Double {
        switch self {
        case .hPa, .dual: return hPa
        case .inHg:        return hPa * 0.029529983
        case .mmHg:        return hPa * 0.750061683
        }
    }

    /// Formatted display string for the primary reading (no unit suffix).
    func primaryString(_ hPa: Double) -> String {
        switch self {
        case .hPa, .dual:
            return String(format: "%.1f", hPa)
        case .inHg:
            return String(format: "%.2f", hPa * 0.029529983)
        case .mmHg:
            return String(format: "%.1f", hPa * 0.750061683)
        }
    }

    /// Secondary unit label + value shown below the primary when in dual mode.
    func secondaryString(_ hPa: Double) -> String? {
        guard self == .dual else { return nil }
        return String(format: "%.2f inHg", hPa * 0.029529983)
    }

    /// Full labeled string, e.g. "1013 hPa" or "29.92 inHg".
    func labeled(_ hPa: Double) -> String {
        switch self {
        case .hPa:
            return String(format: "%.0f hPa", hPa)
        case .inHg:
            return String(format: "%.2f inHg", hPa * 0.029529983)
        case .mmHg:
            return String(format: "%.1f mmHg", hPa * 0.750061683)
        case .dual:
            return String(format: "%.0f hPa · %.2f inHg", hPa, hPa * 0.029529983)
        }
    }

    /// Signed delta, e.g. "-1.2 hPa" or "-0.035 inHg". Dual mode uses hPa.
    func delta(_ hPa: Double) -> String {
        switch self {
        case .hPa, .dual:
            return String(format: "%+.1f hPa", hPa)
        case .inHg:
            return String(format: "%+.3f inHg", hPa * 0.029529983)
        case .mmHg:
            return String(format: "%+.1f mmHg", hPa * 0.750061683)
        }
    }

    /// Signed fine-grained delta for micro-pressure analysis.
    func deltaFine(_ hPa: Double) -> String {
        switch self {
        case .hPa, .dual:
            return String(format: "%+.2f hPa", hPa)
        case .inHg:
            return String(format: "%+.3f inHg", hPa * 0.029529983)
        case .mmHg:
            return String(format: "%+.2f mmHg", hPa * 0.750061683)
        }
    }

    /// Signed rate of change per hour.
    func rate(_ hPaPerHour: Double) -> String {
        switch self {
        case .hPa, .dual:
            return String(format: "%+.1f hPa/h", hPaPerHour)
        case .inHg:
            return String(format: "%+.3f inHg/h", hPaPerHour * 0.029529983)
        case .mmHg:
            return String(format: "%+.1f mmHg/h", hPaPerHour * 0.750061683)
        }
    }

    /// Volatility / jitter.
    func jitter(_ hPa: Double) -> String {
        switch self {
        case .hPa, .dual:
            return String(format: "±%.2f hPa", hPa)
        case .inHg:
            return String(format: "±%.3f inHg", hPa * 0.029529983)
        case .mmHg:
            return String(format: "±%.2f mmHg", hPa * 0.750061683)
        }
    }

    /// Compact gauge dial scale label.
    func gaugeLabel(_ hPa: Double) -> String {
        switch self {
        case .hPa, .dual:
            return "\(Int(hPa))"
        case .inHg:
            return String(format: "%.1f", hPa * 0.029529983)
        case .mmHg:
            return "\(Int(hPa * 0.750061683))"
        }
    }
}
