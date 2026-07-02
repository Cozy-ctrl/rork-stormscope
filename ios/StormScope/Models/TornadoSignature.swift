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
    /// Independent live signals that corroborate a developing severe event
    /// (lightning EMP detections, official station gusts, SPC tornado risk,
    /// active NWS Tornado Watch). Two or more allow a borderline pressure
    /// reading to escalate one tier earlier than the barometer alone would.
    let corroborators: [String]
    /// True when the status was raised a tier because of corroborating signals.
    let escalatedByCorroboration: Bool
    let status: Status

    /// Analyzes recent pressure behavior, optionally fused with atmospheric
    /// instability (CAPE in J/kg, Lifted Index in °C) from the weather model.
    /// High CAPE with a strongly negative Lifted Index means the environment
    /// can support severe rotation, so borderline pressure falls escalate.
    ///
    /// The instability gate matches the weather strip's severity tiers so the
    /// "thresholds tightened" note appears exactly when either metric shows
    /// orange or worse there: CAPE ≥ 2500 J/kg ("very unstable") or
    /// Lifted Index ≤ -4 ("unstable — storms probable").
    ///
    /// Corroboration fusion: the barometer is the primary sensor, but it is
    /// deliberately conservative. When at least two *independent* live signals
    /// agree that severe weather is developing — close-range lightning EMP,
    /// official station gusts ≥ 65 km/h, SPC Day-1 tornado probability ≥ 5%,
    /// or an active NWS Tornado Watch — a borderline pressure fall escalates
    /// one tier early. This trades a small false-positive cost for advance
    /// notice, which is the entire point of a local storm-watch tool.
    static func analyze(
        readings: [PressureReading],
        cape: Double? = nil,
        liftedIndex: Double? = nil,
        lightningStrikeCount: Int = 0,
        observedGustKmh: Double? = nil,
        spcTornadoProbability: Int? = nil,
        hasTornadoWatch: Bool = false,
        now: Date = Date()
    ) -> TornadoSignature {
        let unstable = (cape ?? 0) >= 2500 || (liftedIndex ?? 0) <= -4

        var corroborators: [String] = []
        if lightningStrikeCount >= 3 {
            corroborators.append("close-range lightning (\(lightningStrikeCount) strikes/hr)")
        }
        if let gust = observedGustKmh, gust >= 65 {
            corroborators.append(String(format: "station gusts %.0f km/h", gust))
        }
        if let prob = spcTornadoProbability, prob >= 5 {
            corroborators.append("SPC tornado risk \(prob)%")
        }
        if hasTornadoWatch {
            corroborators.append("NWS Tornado Watch active")
        }
        let hasCorroboration = corroborators.count >= 2
        let shortWindow = readings.filter { now.timeIntervalSince($0.timestamp) <= 600 && $0.timestamp <= now }
        let volatilityWindow = readings.filter { now.timeIntervalSince($0.timestamp) <= 1800 && $0.timestamp <= now }
        let jitter = volatility(of: volatilityWindow)

        guard shortWindow.count >= 4,
              let first = shortWindow.first, let last = shortWindow.last,
              last.timestamp.timeIntervalSince(first.timestamp) >= 300 else {
            return TornadoSignature(drop10m: nil, volatility: jitter, isAtmosphereUnstable: unstable, corroborators: corroborators, escalatedByCorroboration: false, status: .insufficientData)
        }

        let drop = last.hPa - first.hPa
        var escalated = false
        var status: Status
        if drop <= -1.2 {
            // ~1+ hPa in 10 minutes is an extreme, rotation-scale fall.
            status = .signature
        } else if drop <= -0.8 && unstable {
            // A strong fall in an unstable environment (high CAPE / very
            // negative Lifted Index) is treated as a signature.
            status = .signature
        } else if drop <= -0.5 || (jitter ?? 0) >= 0.15 {
            // Readings are recorded once per minute, so jitter is the mean
            // absolute minute-to-minute change. Sensor noise sits near
            // 0.02–0.05 hPa; sustained ≥0.15 hPa/min indicates genuine
            // pressure pumping. (The previous 0.30 was unreachable.)
            status = .elevated
        } else if drop <= -0.3 && unstable {
            status = .elevated
        } else {
            status = .quiet
        }

        // Corroboration escalation: independent live signals raise a
        // borderline reading one tier early.
        if hasCorroboration {
            if status == .elevated && drop <= -0.8 {
                status = .signature
                escalated = true
            } else if status == .quiet && drop <= -0.3 {
                status = .elevated
                escalated = true
            }
        }
        return TornadoSignature(drop10m: drop, volatility: jitter, isAtmosphereUnstable: unstable, corroborators: corroborators, escalatedByCorroboration: escalated, status: status)
    }

    private static func volatility(of readings: [PressureReading]) -> Double? {
        guard readings.count >= 5 else { return nil }
        let diffs = zip(readings.dropFirst(), readings).map { abs($0.hPa - $1.hPa) }
        guard !diffs.isEmpty else { return nil }
        return diffs.reduce(0, +) / Double(diffs.count)
    }
}
