import Foundation

/// Computes the sun's azimuth and elevation for a geographic position and
/// time using the standard low-precision solar ephemeris (accuracy ~0.01°,
/// far tighter than rainbow geometry requires).
nonisolated enum SolarPosition {
    struct Position {
        /// Compass azimuth of the sun, degrees clockwise from true north.
        let azimuth: Double
        /// Elevation of the sun above the horizon, in degrees (negative = below).
        let elevation: Double
    }

    /// Sun position for the given WGS84 coordinates and moment in time.
    static func compute(latitude: Double, longitude: Double, date: Date = Date()) -> Position {
        let rad = Double.pi / 180
        // Days since the J2000.0 epoch.
        let julianDay = 2440587.5 + date.timeIntervalSince1970 / 86400.0
        let n = julianDay - 2451545.0

        // Solar ecliptic coordinates.
        let meanLongitude = normalizeDegrees(280.460 + 0.9856474 * n)
        let meanAnomaly = normalizeDegrees(357.528 + 0.9856003 * n) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly)) * rad
        let obliquity = (23.439 - 0.0000004 * n) * rad

        // Equatorial coordinates.
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))
        let rightAscensionDeg = normalizeDegrees(atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude)) / rad)

        // Local hour angle via Greenwich mean sidereal time.
        let gmstDeg = normalizeDegrees(280.46061837 + 360.98564736629 * n)
        let localSiderealDeg = normalizeDegrees(gmstDeg + longitude)
        let hourAngleDeg = normalizeDegrees(localSiderealDeg - rightAscensionDeg + 180) - 180
        let hourAngle = hourAngleDeg * rad

        // Horizontal coordinates.
        let latRad = latitude * rad
        let sinElevation = sin(latRad) * sin(declination) + cos(latRad) * cos(declination) * cos(hourAngle)
        let elevation = asin(min(1, max(-1, sinElevation)))

        let cosAzimuth = (sin(declination) - sinElevation * sin(latRad)) / (cos(elevation) * cos(latRad))
        var azimuth = acos(min(1, max(-1, cosAzimuth))) / rad
        if sin(hourAngle) > 0 { azimuth = 360 - azimuth }

        return Position(azimuth: azimuth, elevation: elevation / rad)
    }

    /// Short compass name ("WNW") for a degree bearing.
    static func compassName(for degrees: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                     "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((normalizeDegrees(degrees) / 22.5).rounded()) % 16
        return names[index]
    }

    private static func normalizeDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }
}
