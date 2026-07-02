import SwiftUI

/// Observed wind from the nearest reporting NWS station — real anemometer
/// data, not model output. Shows speed, gusts, a direction compass, and how
/// far the forecast model is off from what's actually measured. Sudden wind
/// direction shifts mark fronts and drylines; observed-vs-model spread shows
/// how well the forecast is handling the local situation.
struct StationWindCardView: View {
    let stations: [StationObservation]
    let weather: WeatherSnapshot?
    let units: UnitSystem

    /// Nearest station that reported wind data.
    private var station: StationObservation? {
        stations.first { $0.windSpeedKmh != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let station {
                HStack(spacing: 16) {
                    compass(direction: station.windDirectionDeg)
                    readouts(station)
                }
                modelComparison(station)
                sourceLine(station)
            } else {
                Text("No nearby station is reporting wind right now.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
            Image(systemName: "wind.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.cyan)
            Text("Observed Wind")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("STATION DATA")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .kerning(1)
                .foregroundStyle(Theme.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    /// A compass dial with an arrow showing the direction the wind blows
    /// TOWARD (meteorological direction + 180°), which reads naturally.
    private func compass(direction: Double?) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 2)
            ForEach(["N", "E", "S", "W"], id: \.self) { point in
                Text(point)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(point == "N" ? Theme.cyan : Theme.textTertiary)
                    .offset(y: -31)
                    .rotationEffect(.degrees(cardinalAngle(point)))
            }
            if let direction {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.cyan)
                    .rotationEffect(.degrees(direction + 180))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: direction)
            } else {
                Text("—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: 84, height: 84)
        .accessibilityLabel(direction.map { "Wind from \(WindCompass.cardinal($0))" } ?? "Wind direction unavailable")
    }

    private func cardinalAngle(_ point: String) -> Double {
        switch point {
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }

    private func readouts(_ station: StationObservation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let speed = station.windSpeedKmh {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(units.speed(speed))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    if let direction = station.windDirectionDeg {
                        Text("from \(WindCompass.cardinal(direction)) (\(Int(direction))°)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.cyan)
                    }
                }
            }
            if let gust = station.windGustKmh {
                HStack(spacing: 4) {
                    Image(systemName: "wind.snow")
                        .font(.system(size: 10))
                    Text("Gusting \(units.speed(gust))")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(gust > 55 ? Theme.orange : Theme.textSecondary)
            } else {
                Text("No gusts reported")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How far the forecast model is from the anemometer on the ground.
    @ViewBuilder
    private func modelComparison(_ station: StationObservation) -> some View {
        if let weather, let observed = station.windSpeedKmh {
            VStack(alignment: .leading, spacing: 5) {
                let speedDelta = observed - weather.windSpeed
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.cyan)
                    Text("Model says \(units.speed(weather.windSpeed)) — ")
                        .foregroundStyle(Theme.textSecondary)
                    + Text(speedDeltaLabel(speedDelta))
                        .foregroundStyle(abs(speedDelta) > 15 ? Theme.amber : Theme.textTertiary)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 11, design: .rounded))

                if let observedDir = station.windDirectionDeg, let modelDir = weather.windDirection {
                    let diff = angularDifference(observedDir, modelDir)
                    if diff > 45 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.amber)
                            Text("Observed direction differs from the model by \(Int(diff))° — a real wind shift may be underway (front or boundary).")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.amber.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
    }

    private func speedDeltaLabel(_ delta: Double) -> String {
        if abs(delta) < 3 { return "forecast agrees with the ground" }
        let formatted = units.speed(abs(delta))
        return delta > 0
            ? "actual wind is \(formatted) stronger"
            : "actual wind is \(formatted) lighter"
    }

    /// Smallest angle between two compass headings (0–180°).
    private func angularDifference(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return diff > 180 ? 360 - diff : diff
    }

    private func sourceLine(_ station: StationObservation) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 8))
            Text("\(station.id) · \(String(format: "%.1f km", station.distanceKm)) away")
            if let observed = station.observedAt {
                Text("· \(observed.formatted(.relative(presentation: .named)))")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(Theme.textTertiary)
    }
}

/// Shared helper for converting meteorological degrees to a cardinal label.
nonisolated enum WindCompass {
    static func cardinal(_ degrees: Double) -> String {
        let points = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                      "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return points[index]
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        StationWindCardView(
            stations: [
                StationObservation(
                    id: "KOKC", name: "Will Rogers World Airport",
                    latitude: 35.39, longitude: -97.6, distanceKm: 9.5,
                    pressureHPa: 1004.2, temperatureC: 27.5, dewPointC: 22.1,
                    windSpeedKmh: 42, windGustKmh: 63, windDirectionDeg: 160,
                    humidity: 74, visibilityM: 16000, precipLastHourMm: nil,
                    conditions: "Mostly Cloudy", observedAt: Date().addingTimeInterval(-900)
                ),
            ],
            weather: WeatherSnapshot(
                temperature: 28.5, apparentTemperature: 31.0, humidity: 65,
                windSpeed: 24.0, windGust: 45.0, windDirection: 210,
                precipitationNow: 0, precipitationLast24h: 2.1,
                dewPoint: 21.0, cloudCover: 75, visibility: 8000,
                cape: 2800, liftedIndex: -5.5, stationPressure: 1005.0,
                weatherCode: 3, maxRainChance: 40, fetchedAt: Date()
            ),
            units: .metric
        )
        .padding()
    }
}
