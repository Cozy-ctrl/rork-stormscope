import Foundation

/// User-selectable measurement system with formatting helpers.
/// All internal values stay metric (hPa, °C, km/h) — conversion happens
/// only at display time.
nonisolated enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        self == .metric ? "Metric" : "Imperial"
    }

    var summary: String {
        self == .metric ? "hPa · °C · km/h" : "inHg · °F · mph"
    }

    var pressureUnit: String {
        self == .metric ? "hPa" : "inHg"
    }

    /// Converts an hPa value into the display unit's numeric value.
    func pressureValue(_ hPa: Double) -> Double {
        self == .metric ? hPa : hPa * 0.029529983
    }

    /// Absolute pressure readout, e.g. "1013.2" or "29.92" (no unit suffix).
    func pressure(_ hPa: Double) -> String {
        self == .metric
            ? String(format: "%.1f", hPa)
            : String(format: "%.2f", pressureValue(hPa))
    }

    /// Absolute pressure with unit, e.g. "1013 hPa" / "29.92 inHg".
    func pressureLabeled(_ hPa: Double) -> String {
        self == .metric
            ? String(format: "%.0f hPa", hPa)
            : String(format: "%.2f inHg", pressureValue(hPa))
    }

    /// Signed pressure change with unit, e.g. "-1.2 hPa" / "-0.035 inHg".
    func pressureDelta(_ hPa: Double) -> String {
        self == .metric
            ? String(format: "%+.1f hPa", hPa)
            : String(format: "%+.3f inHg", pressureValue(hPa))
    }

    /// Signed fine-grained pressure change (tornado micro-drops).
    func pressureDeltaFine(_ hPa: Double) -> String {
        self == .metric
            ? String(format: "%+.2f hPa", hPa)
            : String(format: "%+.3f inHg", pressureValue(hPa))
    }

    /// Signed rate of change per hour, e.g. "-1.2 hPa/h" / "-0.035 inHg/h".
    func pressureRate(_ hPaPerHour: Double) -> String {
        self == .metric
            ? String(format: "%+.1f hPa/h", hPaPerHour)
            : String(format: "%+.3f inHg/h", pressureValue(hPaPerHour))
    }

    /// Sample-to-sample volatility, e.g. "±0.08 hPa" / "±0.002 inHg".
    func pressureJitter(_ hPa: Double) -> String {
        self == .metric
            ? String(format: "±%.2f hPa", hPa)
            : String(format: "±%.3f inHg", pressureValue(hPa))
    }

    /// Compact gauge dial scale label for an hPa tick value.
    func gaugeLabel(_ hPa: Double) -> String {
        self == .metric
            ? "\(Int(hPa))"
            : String(format: "%.1f", pressureValue(hPa))
    }

    /// Temperature from Celsius, e.g. "21°" / "70°".
    func temperature(_ celsius: Double) -> String {
        self == .metric
            ? String(format: "%.0f°", celsius)
            : String(format: "%.0f°", celsius * 9 / 5 + 32)
    }

    /// Temperature from Celsius with an explicit unit letter, for reports and
    /// exports where the ambiguity of a bare "°" isn't acceptable, e.g.
    /// "21.0°C" / "69.8°F".
    func temperatureLabeled(_ celsius: Double) -> String {
        self == .metric
            ? String(format: "%.1f°C", celsius)
            : String(format: "%.1f°F", celsius * 9 / 5 + 32)
    }

    /// Wind speed from km/h, e.g. "14 km/h" / "9 mph".
    func speed(_ kmh: Double) -> String {
        self == .metric
            ? String(format: "%.0f km/h", kmh)
            : String(format: "%.0f mph", kmh * 0.621371)
    }

    /// Elevation/altitude from meters, e.g. "120 m" / "394 ft".
    func elevation(_ meters: Double) -> String {
        self == .metric
            ? String(format: "%.0f m", meters)
            : String(format: "%.0f ft", meters * 3.28084)
    }

    /// Distance from kilometers, e.g. "12 km" / "7 mi".
    func distance(_ km: Double) -> String {
        self == .metric
            ? (km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km))
            : (km * 0.621371 < 10 ? String(format: "%.1f mi", km * 0.621371) : String(format: "%.0f mi", km * 0.621371))
    }

    /// Visibility from meters, e.g. "8 km" / "5 mi".
    func visibility(_ meters: Double) -> String {
        let km = meters / 1000.0
        if self == .metric {
            return km < 10 ? String(format: "%.1f km", km) : String(format: "%.0f km", km)
        } else {
            let mi = km * 0.621371
            return mi < 10 ? String(format: "%.1f mi", mi) : String(format: "%.0f mi", mi)
        }
    }

    /// Precipitation rate from mm/h, e.g. "3.2 mm/h" / "0.13 in/h".
    func precipRate(_ mmPerHour: Double) -> String {
        self == .metric
            ? String(format: "%.1f mm/h", mmPerHour)
            : String(format: "%.2f in/h", mmPerHour / 25.4)
    }

    /// Accumulated precipitation from mm, e.g. "8.4 mm" / "0.33 in".
    func precipAmount(_ mm: Double) -> String {
        self == .metric
            ? String(format: "%.1f mm", mm)
            : String(format: "%.2f in", mm / 25.4)
    }
}
