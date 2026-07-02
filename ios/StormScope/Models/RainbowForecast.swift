import Foundation

/// Deterministic rainbow visibility computed from solar geometry plus live
/// precipitation and cloud data.
///
/// Rainbows appear at exactly 42° from the anti-solar point (directly
/// opposite the sun). When the sun's elevation exceeds 42°, no rainbow is
/// visible from the ground — pure geometry, no guessing. Everything needed
/// is already on hand: GPS + time give the sun position, the weather model
/// and station gauges confirm rain, cloud cover gates sun visibility.
nonisolated struct RainbowForecast {
    enum Verdict {
        /// Sun below 42°, rain falling, sun side mostly clear — look now.
        case likely
        /// Geometry works but conditions are marginal (heavy cloud or rain
        /// only nearby rather than overhead).
        case possible
        /// Sun above 42° elevation — geometrically impossible from the ground.
        case sunTooHigh
        /// Sun below the horizon.
        case night
        /// No precipitation detected nearby.
        case noRain
        /// Overcast so thick the sun can't break through to light the drops.
        case sunObscured
    }

    let verdict: Verdict
    /// Sun compass azimuth, degrees clockwise from true north.
    let sunAzimuth: Double
    /// Sun elevation above the horizon, in degrees.
    let sunElevation: Double
    /// Anti-solar azimuth — the compass direction to look for the bow.
    let lookAzimuth: Double
    /// Elevation of the top of the primary bow above the horizon (42° − sun elevation).
    let arcTopElevation: Double
    /// True when rain is confirmed falling at or near the user right now.
    let isRainPresent: Bool
    /// Total cloud cover percentage, when known.
    let cloudCover: Int?
    /// True when tornado-scale pressure behaviour coincides with rainbow
    /// optics — the "rainbow wrap" secondary indicator. A bow forming inside
    /// the rain curtain wrapping a supercell's updraft is a chaser-recognised
    /// sign of organised severe rotation.
    let isWrapIndicatorActive: Bool

    /// Compass name for the viewing direction, e.g. "WNW".
    var lookDirectionName: String {
        SolarPosition.compassName(for: lookAzimuth)
    }

    /// Whether the dashboard should surface the card at all.
    var isDisplayWorthy: Bool {
        switch verdict {
        case .likely, .possible: return true
        default: return isWrapIndicatorActive
        }
    }

    /// One-line viewing instruction for the card and AI context.
    var lookInstruction: String {
        String(format: "Look %@ (%.0f°), bow top ~%.0f° above the horizon", lookDirectionName, lookAzimuth, arcTopElevation)
    }

    /// Computes the current forecast from solar geometry and live conditions.
    /// - Parameters:
    ///   - tornadoStatus: current pressure-signature status, used only for
    ///     the wrap indicator — it never changes the optical verdict.
    static func compute(
        latitude: Double,
        longitude: Double,
        weather: WeatherSnapshot?,
        stations: [StationObservation],
        tornadoStatus: TornadoSignature.Status,
        date: Date = Date()
    ) -> RainbowForecast {
        let sun = SolarPosition.compute(latitude: latitude, longitude: longitude, date: date)
        let lookAzimuth = (sun.azimuth + 180).truncatingRemainder(dividingBy: 360)
        let arcTop = max(0, 42 - sun.elevation)

        // Rain falling right now: model rate, a nearby station gauge, or a
        // rain/shower weather code.
        let modelRain = (weather?.precipitationNow ?? 0) >= 0.1
        let stationRain = stations.contains { station in
            guard station.distanceKm <= 30, let precip = station.precipLastHourMm else { return false }
            return precip >= 0.2
        }
        let codeRain = weather.map { isRainCode($0.weatherCode) } ?? false
        let rainPresent = modelRain || stationRain || codeRain
        // Rain likely close by even if not overhead — enough for "possible".
        let rainNearby = (weather?.maxRainChance ?? 0) >= 60

        let cloudCover = weather?.cloudCover
        let sunElevatedEnough = sun.elevation > 0.5
        let geometryOK = sunElevatedEnough && sun.elevation < 42

        let wrapActive = geometryOK && rainPresent
            && (tornadoStatus == .elevated || tornadoStatus == .signature)

        let verdict: Verdict
        if !sunElevatedEnough {
            verdict = .night
        } else if sun.elevation >= 42 {
            verdict = .sunTooHigh
        } else if !rainPresent && !rainNearby {
            verdict = .noRain
        } else if let cover = cloudCover, cover >= 95 {
            verdict = .sunObscured
        } else if rainPresent, (cloudCover ?? 100) < 75 {
            verdict = .likely
        } else {
            verdict = .possible
        }

        return RainbowForecast(
            verdict: verdict,
            sunAzimuth: sun.azimuth,
            sunElevation: sun.elevation,
            lookAzimuth: lookAzimuth,
            arcTopElevation: arcTop,
            isRainPresent: rainPresent,
            cloudCover: cloudCover,
            isWrapIndicatorActive: wrapActive
        )
    }

    /// WMO codes for drizzle, rain, freezing rain, and rain showers.
    private static func isRainCode(_ code: Int) -> Bool {
        switch code {
        case 51...67, 80...82, 95...99: return true
        default: return false
        }
    }
}
