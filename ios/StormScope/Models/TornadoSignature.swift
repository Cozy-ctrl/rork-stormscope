import Foundation

/// Short-window pressure analysis tuned for tornado-scale phenomena.
///
/// Tornadic mesocyclones produce abrupt localized pressure falls over
/// minutes — much faster than a synoptic front's hours-long decline — often
/// with elevated sample-to-sample jitter. A single barometer can't confirm a
/// tornado, but it can flag pressure behavior consistent with severe rotation
/// nearby, which is why this is paired with official NWS alerts.
nonisolated struct TornadoSignature {
    enum Status: String {
        case insufficientData
        case quiet
        case elevated
        case signature
    }

    /// Pressure change over roughly the last 10 minutes, in hPa.
    let drop10m: Double?
    /// Mean absolute sample-to-sample change over the last 30 minutes, in hPa.
    let volatility: Double?
    /// True when CAPE/Lifted Index indicate an unstable atmosphere, which
    /// tightens the pressure-drop thresholds below.
    let isAtmosphereUnstable: Bool
    let status: Status

    /// Analyzes recent pressure behavior, optionally fused with atmospheric
    /// instability (CAPE in J/kg, Lifted Index in °C) from the weather model.
    /// High CAPE with a strongly negative Lifted Index means the environment
    /// can support severe rotation, so borderline pressure falls escalate.
    static func analyze(
        readings: [PressureReading],
        cape: Double? = nil,
        liftedIndex: Double? = nil,
        now: Date = Date()
    ) -> TornadoSignature {
        let unstable = (cape ?? 0) >= 2000 || (liftedIndex ?? 0) <= -4
        let shortWindow = readings.filter { now.timeIntervalSince($0.timestamp) <= 600 && $0.timestamp <= now }
        let volatilityWindow = readings.filter { now.timeIntervalSince($0.timestamp) <= 1800 && $0.timestamp <= now }
        let jitter = volatility(of: volatilityWindow)

        guard shortWindow.count >= 4,
              let first = shortWindow.first, let last = shortWindow.last,
              last.timestamp.timeIntervalSince(first.timestamp) >= 300 else {
            return TornadoSignature(drop10m: nil, volatility: jitter, isAtmosphereUnstable: unstable, status: .insufficientData)
        }

        let drop = last.hPa - first.hPa
        let status: Status
        if drop <= -1.2 {
            // ~1+ hPa in 10 minutes is an extreme, rotation-scale fall.
            status = .signature
        } else if drop <= -0.8 && unstable {
            // A strong fall in an unstable environment (high CAPE / very
            // negative Lifted Index) is treated as a signature.
            status = .signature
        } else if drop <= -0.5 || (jitter ?? 0) >= 0.30 {
            status = .elevated
        } else if drop <= -0.3 && unstable {
            status = .elevated
        } else {
            status = .quiet
        }
        return TornadoSignature(drop10m: drop, volatility: jitter, isAtmosphereUnstable: unstable, status: status)
    }

    private static func volatility(of readings: [PressureReading]) -> Double? {
        guard readings.count >= 5 else { return nil }
        let diffs = zip(readings.dropFirst(), readings).map { abs($0.hPa - $1.hPa) }
        guard !diffs.isEmpty else { return nil }
        return diffs.reduce(0, +) / Double(diffs.count)
    }
}
