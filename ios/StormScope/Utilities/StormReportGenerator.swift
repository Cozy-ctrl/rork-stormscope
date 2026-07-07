import Foundation

/// Generates a branded, shareable weather report from the live dashboard data.
/// Produces both a plain-text version (works everywhere) and an attributed
/// version (rich formatting for Messages, Mail, etc.).
nonisolated struct StormReportGenerator {

    /// Full input snapshot from the dashboard — every field that matters for
    /// a comprehensive weather report.
    struct Snapshot {
        let date: Date
        let formattedDate: String
        let placeName: String?
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
        let isApproximate: Bool
        let isSimulated: Bool
        let hasBarometer: Bool

        // Pressure
        let pressure: Double?
        let pressureMode: PressureDisplayMode
        let isMSLP: Bool
        let isCalibrated: Bool
        let calibrationStation: String?

        // Storm assessment
        let levelTitle: String
        let ratePerHour: Double?
        let delta1h: Double?
        let delta3h: Double?
        let delta6h: Double?
        let escalatedByCorroboration: Bool
        let corroborators: [String]

        // Tornado signature
        let tornadoStatus: String
        let tornadoDrop10m: Double?
        let tornadoVolatility: Double?
        let tornadoUnstable: Bool
        let tornadoCorroborators: [String]
        let tornadoEscalated: Bool

        // Weather
        let temperature: Double?
        let apparentTemperature: Double?
        let humidity: Int?
        let windSpeed: Double?
        let windGust: Double?
        let windDirection: Double?
        let dewPoint: Double?
        let visibility: Double?
        let cloudCover: Int?
        let weatherDescription: String?
        let precipitationNow: Double?
        let precipitationLast24h: Double?
        let cape: Double?
        let liftedIndex: Double?

        // NWS alerts
        let alertCount: Int
        let hasTornadoWarning: Bool
        let hasTornadoWatch: Bool
        let alertHeadlines: [String]

        // SPC outlook
        let outlookText: String?

        // Lightning
        let strikeCount: Int
        let lastStrikeKm: Double?
        let proximityLabel: String
        let lightningEnabled: Bool
        let hasMagnetometer: Bool

        // Station cross-check
        let stationCount: Int
        let stationAgreementVerdict: String
        let stationMaxDelta: Double?
        let pressureGradientLabel: String?
        let pressureGradientMagnitude: Double?

        // Event confirmation
        let confirmationVerdict: String?
        let confirmationDetail: String?

        // Rainbow
        let rainbowVerdict: String?
        let rainbowLook: String?
        let rainbowWrap: Bool

        // Radar
        let radarOffline: Bool
        let radarSiteID: String?

        // Units
        let unitSystem: UnitSystem
    }

    // MARK: - Plain text report

    static func plainTextReport(from snapshot: Snapshot) -> String {
        var lines: [String] = []

        // ── Branded header ──
        lines.append("⛈  StormScope Weather Report")
        lines.append("━━━━━━━━━━━━━━━━━━━━━━━━")
        lines.append("Generated: \(snapshot.formattedDate)")
        if let place = snapshot.placeName {
            let locNote = snapshot.isApproximate ? " (approximate)" : ""
            lines.append("Location: \(place)\(locNote)")
        }
        if let alt = snapshot.altitude {
            lines.append("Elevation: \(snapshot.unitSystem.elevation(alt))")
        }

        // ── Sensor status ──
        let sensorLine: String = {
            if !snapshot.hasBarometer { return "Sensor: DEMO MODE (no barometer)" }
            if snapshot.isSimulated { return "Sensor: SIMULATED FEED" }
            return "Sensor: LIVE BAROMETER"
        }()
        lines.append(sensorLine)
        if snapshot.isCalibrated, let station = snapshot.calibrationStation {
            lines.append("Calibrated to: \(station)")
        }

        lines.append("")

        // ── Pressure ──
        lines.append("── PRESSURE ──")
        if let p = snapshot.pressure {
            let mslpNote = snapshot.isMSLP ? " (MSLP)" : ""
            lines.append("Current: \(snapshot.pressureMode.primaryString(p)) \(snapshot.pressureMode.primaryUnit)\(mslpNote)")
        }
        if let rate = snapshot.ratePerHour {
            lines.append("1-hour trend: \(snapshot.pressureMode.rate(rate))")
        }
        if let d1 = snapshot.delta1h {
            lines.append("1-hour change: \(snapshot.pressureMode.delta(d1))")
        }
        if let d3 = snapshot.delta3h {
            lines.append("3-hour change: \(snapshot.pressureMode.delta(d3))")
        }
        if let d6 = snapshot.delta6h {
            lines.append("6-hour change: \(snapshot.pressureMode.delta(d6))")
        }
        lines.append("Status: \(snapshot.levelTitle)")
        if snapshot.escalatedByCorroboration, !snapshot.corroborators.isEmpty {
            lines.append("Note: Level raised early by corroborating signals:")
            for c in snapshot.corroborators {
                lines.append("  • \(c)")
            }
        }

        lines.append("")

        // ── Tornado signature ──
        lines.append("── TORNADO WATCH ──")
        lines.append("Signature status: \(snapshot.tornadoStatus)")
        if let drop = snapshot.tornadoDrop10m {
            lines.append("10-minute drop: \(snapshot.pressureMode.deltaFine(drop))")
        }
        if let vol = snapshot.tornadoVolatility {
            lines.append("Volatility: \(snapshot.pressureMode.jitter(vol))/min")
        }
        lines.append("Atmosphere unstable: \(snapshot.tornadoUnstable ? "YES" : "no")")
        if snapshot.tornadoEscalated, !snapshot.tornadoCorroborators.isEmpty {
            lines.append("Status raised early by:")
            for c in snapshot.tornadoCorroborators {
                lines.append("  • \(c)")
            }
        }

        lines.append("")

        // ── Weather conditions ──
        lines.append("── CONDITIONS ──")
        if let desc = snapshot.weatherDescription {
            lines.append("Sky: \(desc)")
        }
        if let temp = snapshot.temperature {
            lines.append("Temperature: \(snapshot.unitSystem.temperatureLabeled(temp))")
        }
        if let feels = snapshot.apparentTemperature {
            lines.append("Feels like: \(snapshot.unitSystem.temperatureLabeled(feels))")
        }
        if let hum = snapshot.humidity {
            lines.append("Humidity: \(hum)%")
        }
        if let dew = snapshot.dewPoint {
            lines.append("Dew point: \(snapshot.unitSystem.temperatureLabeled(dew))")
        }
        if let wind = snapshot.windSpeed {
            var windLine = "Wind: \(snapshot.unitSystem.speed(wind))"
            if let dir = snapshot.windDirection {
                windLine += String(format: " from %.0f°", dir)
            }
            if let gust = snapshot.windGust {
                windLine += ", gusting \(snapshot.unitSystem.speed(gust))"
            }
            lines.append(windLine)
        }
        if let vis = snapshot.visibility {
            lines.append("Visibility: \(snapshot.unitSystem.visibility(vis))")
        }
        if let cover = snapshot.cloudCover {
            lines.append("Cloud cover: \(cover)%")
        }
        if let precip = snapshot.precipitationNow, precip >= 0.1 {
            lines.append("Precipitation (now): \(snapshot.unitSystem.precipRate(precip))")
        }
        if let precip24 = snapshot.precipitationLast24h, precip24 >= 1 {
            lines.append("Precipitation (24 h): \(snapshot.unitSystem.precipAmount(precip24))")
        }
        if let cape = snapshot.cape {
            lines.append("CAPE: \(Int(cape)) J/kg")
        }
        if let li = snapshot.liftedIndex {
            lines.append(String(format: "Lifted Index: %.1f", li))
        }

        lines.append("")

        // ── NWS Alerts ──
        lines.append("── NWS ALERTS ──")
        if snapshot.alertCount > 0 {
            lines.append("Active alerts: \(snapshot.alertCount)")
            if snapshot.hasTornadoWarning {
                lines.append("⚠️  TORNADO WARNING ACTIVE")
            }
            if snapshot.hasTornadoWatch {
                lines.append("⚠️  Tornado Watch active")
            }
            for headline in snapshot.alertHeadlines.prefix(5) {
                lines.append("  • \(headline)")
            }
            if snapshot.alertHeadlines.count > 5 {
                lines.append("  … and \(snapshot.alertHeadlines.count - 5) more")
            }
        } else {
            lines.append("No active NWS alerts for this area.")
        }

        if let outlook = snapshot.outlookText {
            lines.append("SPC Outlook: \(outlook)")
        }

        lines.append("")

        // ── Lightning ──
        lines.append("── LIGHTNING ──")
        if snapshot.lightningEnabled && snapshot.hasMagnetometer {
            if snapshot.strikeCount > 0 {
                lines.append("Strikes detected: \(snapshot.strikeCount) in the last hour")
                if let dist = snapshot.lastStrikeKm {
                    lines.append(String(format: "Last strike: ~%.1f km away", dist))
                }
                lines.append("Proximity: \(snapshot.proximityLabel)")
            } else {
                lines.append("No strikes detected — listening.")
            }
        } else {
            lines.append("Lightning detection is \(snapshot.lightningEnabled ? "unavailable on this device" : "disabled").")
        }

        lines.append("")

        // ── Station cross-check ──
        lines.append("── STATION CROSS-CHECK ──")
        if snapshot.stationCount > 0 {
            lines.append("Nearby NWS stations: \(snapshot.stationCount)")
            lines.append("Agreement: \(snapshot.stationAgreementVerdict)")
            if let delta = snapshot.stationMaxDelta {
                lines.append("Worst offset: ±\(snapshot.pressureMode.magnitude(delta))")
            }
        } else {
            lines.append("No nearby station data available.")
        }
        if let gradientLabel = snapshot.pressureGradientLabel, let gradientMag = snapshot.pressureGradientMagnitude {
            lines.append("Pressure gradient: falling toward \(gradientLabel) at \(snapshot.pressureMode.gradientMagnitude(gradientMag))")
        }

        lines.append("")

        // ── Event confirmation ──
        if let verdict = snapshot.confirmationVerdict {
            lines.append("── EXTREME EVENT CHECK ──")
            lines.append("Station confirmation: \(verdict)")
            if let detail = snapshot.confirmationDetail {
                lines.append(detail)
            }
            lines.append("")
        }

        // ── Rainbow ──
        if let verdict = snapshot.rainbowVerdict {
            lines.append("── RAINBOW WATCH ──")
            lines.append("Rainbow: \(verdict)")
            if let look = snapshot.rainbowLook {
                lines.append(look)
            }
            if snapshot.rainbowWrap {
                lines.append("Rainbow wrap indicator active — possible supercell organization.")
            }
            lines.append("")
        }

        // ── Radar ──
        if snapshot.radarOffline, let siteID = snapshot.radarSiteID {
            lines.append("── RADAR STATUS ──")
            lines.append("Note: NEXRAD site \(siteID) is offline — imagery from neighboring sites.")
            lines.append("")
        }

        // ── Footer ──
        lines.append("━━━━━━━━━━━━━━━━━━━━━━━━")
        lines.append("Report generated by StormScope")
        lines.append("An on-device storm watch tool for iPhone")
        lines.append("")
        lines.append("⚠️  Always follow official NWS alerts and civil authority instructions for life-safety decisions. This report is a supplemental aid, not a replacement for professional weather services.")

        return lines.joined(separator: "\n")
    }
}
