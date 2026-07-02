import Foundation

/// Result of analyzing recent pressure readings for storm-front signatures.
///
/// Meteorological rule of thumb: a fall faster than ~1 hPa/hour sustained
/// over an hour signals an approaching low; faster than ~2–3 hPa/hour is a
/// strong front. Rises indicate clearing.
nonisolated struct StormAssessment {
    /// Least-squares slope over the last hour, in hPa per hour.
    let ratePerHour: Double?
    /// Pressure change over roughly the last hour, in hPa.
    let delta1h: Double?
    /// Pressure change over roughly the last three hours, in hPa.
    let delta3h: Double?
    let level: StormLevel

    static func assess(readings: [PressureReading], now: Date = Date()) -> StormAssessment {
        let rate = hourlySlope(of: readings, now: now)
        let d1 = delta(in: readings, hoursAgo: 1, now: now)
        let d3 = delta(in: readings, hoursAgo: 3, now: now)

        guard let rate else {
            return StormAssessment(ratePerHour: nil, delta1h: d1, delta3h: d3, level: .collecting)
        }

        var level: StormLevel
        switch rate {
        case 0.8...:
            level = .rising
        case -0.6..<0.8:
            level = .steady
        case -1.5..<(-0.6):
            level = .falling
        case -3.0..<(-1.5):
            level = .stormLikely
        default:
            level = .frontImminent
        }

        // A large sustained 3-hour drop is a storm signal even if the
        // last hour has momentarily flattened out.
        if let d3, d3 <= -5.0, level < .stormLikely {
            level = .stormLikely
        }

        return StormAssessment(ratePerHour: rate, delta1h: d1, delta3h: d3, level: level)
    }

    /// Least-squares linear regression slope over the last 60 minutes,
    /// expressed in hPa/hour. Requires at least 3 samples spanning 15+ minutes.
    private static func hourlySlope(of readings: [PressureReading], now: Date) -> Double? {
        let window = readings.filter { now.timeIntervalSince($0.timestamp) <= 3600 && $0.timestamp <= now }
        guard window.count >= 3,
              let first = window.first, let last = window.last,
              last.timestamp.timeIntervalSince(first.timestamp) >= 900 else {
            return nil
        }

        let xs = window.map { $0.timestamp.timeIntervalSince(first.timestamp) }
        let ys = window.map { $0.hPa }
        let n = Double(window.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumXX - sumX * sumX
        guard abs(denominator) > .ulpOfOne else { return nil }

        let slopePerSecond = (n * sumXY - sumX * sumY) / denominator
        return slopePerSecond * 3600
    }

    /// Change from the reading closest to `hoursAgo` (within a 30-minute
    /// tolerance) to the most recent reading.
    private static func delta(in readings: [PressureReading], hoursAgo: Double, now: Date) -> Double? {
        guard let latest = readings.last else { return nil }
        let target = now.addingTimeInterval(-hoursAgo * 3600)
        let candidate = readings.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(target)) < abs(rhs.timestamp.timeIntervalSince(target))
        }
        guard let candidate, abs(candidate.timestamp.timeIntervalSince(target)) <= 1800 else { return nil }
        return latest.hPa - candidate.hPa
    }
}
