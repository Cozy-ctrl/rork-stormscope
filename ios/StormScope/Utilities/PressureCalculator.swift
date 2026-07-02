import Foundation

/// Pure functions for atmospheric pressure conversions, including
/// Mean Sea Level Pressure (MSLP) reduction via the hypsometric equation.
nonisolated enum PressureCalculator {

    /// Reduces station-level pressure to Mean Sea Level Pressure (MSLP)
    /// using the barometric formula with actual or standard temperature.
    ///
    /// Without MSLP correction, readings vary ~1.2 hPa per 100 m of
    /// elevation — making comparisons across locations meaningless.
    ///
    /// - Parameters:
    ///   - stationPressureHPa: Raw station (device) pressure in hPa.
    ///   - altitudeM: GPS-derived absolute altitude in meters.
    ///   - temperatureC: Surface air temperature in Celsius. When nil,
    ///     the standard atmosphere temperature of 15 °C is assumed.
    /// - Returns: Sea-level-equivalent pressure in hPa.
    static func mslp(
        stationPressureHPa: Double,
        altitudeM: Double,
        temperatureC: Double?
    ) -> Double {
        guard altitudeM > 0.5 else { return stationPressureHPa }

        let tK = (temperatureC ?? 15.0) + 273.15
        // Barometric reduction: MSLP = P × exp(g₀·h / (R·T))
        let exponent = 9.80665 * altitudeM / (287.05 * tK)
        return stationPressureHPa * exp(exponent)
    }

    /// Inverse: estimates station pressure from a known MSLP and altitude.
    /// Useful when comparing a device MSLP to a station that also reports
    /// in MSLP (the altitudes cancel out and the delta is pure drift).
    static func stationPressure(
        mslpHPa: Double,
        altitudeM: Double,
        temperatureC: Double?
    ) -> Double {
        guard altitudeM > 0.5 else { return mslpHPa }
        let tK = (temperatureC ?? 15.0) + 273.15
        let exponent = -9.80665 * altitudeM / (287.05 * tK)
        return mslpHPa * exp(exponent)
    }
}
