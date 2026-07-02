import SwiftUI

/// Precipitation accumulation: the rate falling right now, the observed
/// last-hour total from the nearest NWS rain gauge, and the 24-hour storm
/// total. Rate and storm total come from the weather model; the last-hour
/// value is a real measured gauge reading when a station reports one.
struct PrecipCardView: View {
    let weather: WeatherSnapshot?
    let stations: [StationObservation]
    let units: UnitSystem

    /// Nearest station that reported a last-hour precipitation measurement.
    private var gaugeStation: StationObservation? {
        stations.first { $0.precipLastHourMm != nil }
    }

    private var rateNow: Double? { weather?.precipitationNow }
    private var stormTotal: Double? { weather?.precipitationLast24h }

    /// Everything is dry — collapse to a single quiet line.
    private var isDry: Bool {
        (rateNow ?? 0) < 0.05
            && (stormTotal ?? 0) < 0.1
            && (gaugeStation?.precipLastHourMm ?? 0) < 0.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if weather == nil && gaugeStation == nil {
                Text("Waiting for weather data…")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else if isDry {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.amber)
                    Text("No precipitation in the last 24 hours at this location.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 10) {
                    precipTile(
                        title: "Now",
                        value: rateNow.map { rateLabel($0) },
                        caption: "model rate",
                        highlight: (rateNow ?? 0) >= 7.6
                    )
                    precipTile(
                        title: "Last Hour",
                        value: gaugeStation?.precipLastHourMm.map { amountLabel($0) },
                        caption: gaugeStation.map { "gauge \($0.id)" } ?? "no gauge",
                        highlight: (gaugeStation?.precipLastHourMm ?? 0) >= 12.7
                    )
                    precipTile(
                        title: "24h Total",
                        value: stormTotal.map { amountLabel($0) },
                        caption: "storm total",
                        highlight: (stormTotal ?? 0) >= 50
                    )
                }

                if let note = intensityNote {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.orange)
                        Text(note)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.orange.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.cyan)
            Text("Precipitation")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            if gaugeStation != nil {
                Text("GAUGE + MODEL")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(Theme.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.green.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private func precipTile(title: String, value: String?, caption: String, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            Text(value ?? "—")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(highlight ? Theme.orange : Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(caption)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    /// Heavy-rain callout using standard NWS intensity thresholds.
    private var intensityNote: String? {
        if let rate = rateNow, rate >= 7.6 {
            return "Heavy rain falling now (\(rateLabel(rate))) — reduced visibility and rapid runoff possible."
        }
        if let total = stormTotal, total >= 50 {
            return "Significant 24-hour accumulation (\(amountLabel(total))) — flash flooding risk in low-lying areas."
        }
        return nil
    }

    // MARK: - Formatting

    /// Rain rate from mm/h, e.g. "3.2 mm/h" / "0.13 in/h".
    private func rateLabel(_ mmPerHour: Double) -> String {
        units == .metric
            ? String(format: "%.1f mm/h", mmPerHour)
            : String(format: "%.2f in/h", mmPerHour / 25.4)
    }

    /// Accumulated amount from mm, e.g. "8.4 mm" / "0.33 in".
    private func amountLabel(_ mm: Double) -> String {
        units == .metric
            ? String(format: "%.1f mm", mm)
            : String(format: "%.2f in", mm / 25.4)
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        VStack(spacing: 16) {
            PrecipCardView(
                weather: WeatherSnapshot(
                    temperature: 22, apparentTemperature: 23, humidity: 88,
                    windSpeed: 30, windGust: 52, windDirection: 180,
                    precipitationNow: 9.1, precipitationLast24h: 63.5,
                    dewPoint: 20, cloudCover: 100, visibility: 3000,
                    cape: 1800, liftedIndex: -4.0, stationPressure: 1002,
                    weatherCode: 63, maxRainChance: 95, fetchedAt: Date()
                ),
                stations: [
                    StationObservation(
                        id: "KOKC", name: "Will Rogers World Airport",
                        latitude: 35.39, longitude: -97.6, distanceKm: 9.5,
                        pressureHPa: 1002.2, temperatureC: 21.5, dewPointC: 20.1,
                        windSpeedKmh: 32, windGustKmh: 50, windDirectionDeg: 175,
                        humidity: 90, visibilityM: 4000, precipLastHourMm: 14.2,
                        conditions: "Heavy Rain", observedAt: Date()
                    ),
                ],
                units: .imperial
            )
            PrecipCardView(weather: nil, stations: [], units: .metric)
        }
        .padding()
    }
}
