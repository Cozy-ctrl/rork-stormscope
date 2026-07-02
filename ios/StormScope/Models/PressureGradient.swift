import Foundation

/// The horizontal pressure-gradient vector computed from the device barometer
/// and nearby NWS station observations. The bearing points toward FALLING
/// pressure — the direction weather systems generally approach from.
nonisolated struct PressureGradient {
    /// Compass bearing in degrees (0 = north) toward lower pressure.
    let towardLowBearingDeg: Double
    /// Gradient strength in hPa per 100 km.
    let magnitudeHPaPer100km: Double

    /// Short compass label for the falling-pressure direction, e.g. "SW".
    var compassLabel: String {
        switch towardLowBearingDeg {
        case 0..<22.5, 337.5...: return "N"
        case 22.5..<67.5:        return "NE"
        case 67.5..<112.5:       return "E"
        case 112.5..<157.5:      return "SE"
        case 157.5..<202.5:      return "S"
        case 202.5..<247.5:      return "SW"
        case 247.5..<292.5:      return "W"
        default:                 return "NW"
        }
    }

    /// True when the gradient is strong enough to be meteorologically meaningful.
    var isSignificant: Bool {
        magnitudeHPaPer100km >= 0.8
    }

    /// Inverse-distance-weighted vector sum of pressure slopes from the device
    /// toward each reporting station. Returns nil when fewer than two stations
    /// report pressure or the field is essentially flat.
    ///
    /// The device pressure is bias-corrected first: any uniform offset between
    /// the sensor and the station network (altitude or calibration drift) is
    /// removed by shifting the device value by the mean station delta. This
    /// keeps a drifting sensor from fabricating a radial "gradient" that
    /// contradicts the divergence chart's own drift verdict — only genuine
    /// spatial variation across stations survives.
    static func compute(
        stations: [StationObservation],
        deviceLatitude: Double,
        deviceLongitude: Double,
        devicePressure: Double
    ) -> PressureGradient? {
        let usable = stations.filter { $0.pressureHPa != nil }
        guard usable.count >= 2 else { return nil }

        let deltas = usable.compactMap { $0.pressureHPa.map { $0 - devicePressure } }
        let meanDelta = deltas.reduce(0, +) / Double(deltas.count)
        let correctedDevice = devicePressure + meanDelta

        var vectorEast = 0.0
        var vectorNorth = 0.0
        var weightSum = 0.0

        for station in usable {
            guard let stationPressure = station.pressureHPa else { continue }
            let northKm = (station.latitude - deviceLatitude) * 110.574
            let eastKm = (station.longitude - deviceLongitude) * 111.320 * cos(deviceLatitude * .pi / 180)
            let distanceKm = max((northKm * northKm + eastKm * eastKm).squareRoot(), 0.5)
            // Positive slope means pressure falls in the direction of this station.
            let slope = (correctedDevice - stationPressure) / distanceKm
            let weight = 1.0 / distanceKm
            vectorEast += (eastKm / distanceKm) * slope * weight
            vectorNorth += (northKm / distanceKm) * slope * weight
            weightSum += weight
        }

        guard weightSum > 0 else { return nil }
        vectorEast /= weightSum
        vectorNorth /= weightSum

        let magnitudePer100km = (vectorEast * vectorEast + vectorNorth * vectorNorth).squareRoot() * 100
        guard magnitudePer100km > 0.05 else { return nil }

        var bearing = atan2(vectorEast, vectorNorth) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return PressureGradient(
            towardLowBearingDeg: bearing,
            magnitudeHPaPer100km: magnitudePer100km
        )
    }
}
