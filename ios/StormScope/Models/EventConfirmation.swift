import Foundation

/// Hour-over-hour pressure trend measured at a single NWS station,
/// derived from its recent observation history (not just the latest report).
nonisolated struct StationPressureTrend: Identifiable {
    /// Station identifier, e.g. "KSFO".
    let id: String
    let name: String
    /// Great-circle distance from the user's position, in kilometers.
    let distanceKm: Double
    /// Most recent measured pressure, in hPa.
    let latestHPa: Double
    /// Pressure change over roughly the last hour at the station, in hPa.
    /// nil when the station hasn't reported enough recent observations.
    let deltaHPa: Double?
    let observedAt: Date?

    /// A station-scale fall of 0.8 hPa/hour or faster corroborates a
    /// synoptic or mesoscale pressure event detected by the device.
    var isFalling: Bool {
        guard let deltaHPa else { return false }
        return deltaHPa <= -0.8
    }
}

/// Cross-validation of a device-detected extreme pressure event against
/// nearby NWS station trends. If multiple official stations show the same
/// fall, the signal is regional and real; if stations are steady, the event
/// is either hyper-local (possible tornado-scale) or a sensor artifact.
nonisolated struct EventConfirmation {
    enum Verdict {
        /// Multiple stations show the same pressure fall — regional event confirmed.
        case confirmed
        /// At least one station is falling; others steady — event may be moving in.
        case partial
        /// Stations are steady — signal is localized or a sensor artifact.
        case notConfirmed
        /// Not enough recent station reports to judge.
        case insufficientData
    }

    let checkedAt: Date
    let trends: [StationPressureTrend]
    let verdict: Verdict

    var reportingCount: Int { trends.filter { $0.deltaHPa != nil }.count }
    var fallingCount: Int { trends.filter { $0.isFalling }.count }

    var title: String {
        switch verdict {
        case .confirmed: return "Confirmed by Stations"
        case .partial: return "Partially Confirmed"
        case .notConfirmed: return "Not Seen at Stations"
        case .insufficientData: return "Awaiting Station Data"
        }
    }

    var detail: String {
        switch verdict {
        case .confirmed:
            return "\(fallingCount) of \(reportingCount) nearby NWS stations show the same pressure fall — this is a real regional event, not sensor noise."
        case .partial:
            return "\(fallingCount) of \(reportingCount) stations show a matching fall. The system may be moving in, or the event is on a smaller scale."
        case .notConfirmed:
            return "Nearby stations are holding steady. Your drop may be hyper-local (small-scale phenomena) or a sensor artifact — keep watching."
        case .insufficientData:
            return "Nearby stations haven't posted enough recent observations yet. Rechecking automatically."
        }
    }

    /// One-line summary fed to the on-device intelligence briefing.
    var summaryLine: String {
        switch verdict {
        case .confirmed:
            return "NWS station cross-check: CONFIRMED — \(fallingCount) of \(reportingCount) nearby stations show the same pressure fall."
        case .partial:
            return "NWS station cross-check: partial — \(fallingCount) of \(reportingCount) stations falling."
        case .notConfirmed:
            return "NWS station cross-check: nearby stations steady — device drop may be localized or sensor noise."
        case .insufficientData:
            return "NWS station cross-check: insufficient recent station data."
        }
    }

    /// Builds a verdict from per-station trends.
    static func build(trends: [StationPressureTrend], checkedAt: Date = Date()) -> EventConfirmation {
        let reporting = trends.filter { $0.deltaHPa != nil }
        let falling = reporting.filter { $0.isFalling }

        let verdict: Verdict
        if reporting.isEmpty {
            verdict = .insufficientData
        } else if reporting.count == 1 {
            verdict = falling.isEmpty ? .notConfirmed : .partial
        } else if falling.count >= 2 && falling.count * 2 >= reporting.count {
            verdict = .confirmed
        } else if !falling.isEmpty {
            verdict = .partial
        } else {
            verdict = .notConfirmed
        }
        return EventConfirmation(checkedAt: checkedAt, trends: trends, verdict: verdict)
    }
}
