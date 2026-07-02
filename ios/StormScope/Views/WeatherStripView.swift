import SwiftUI

/// Local conditions grid plus dew point, CAPE, cloud cover, wind gusts, and
/// device-sensor vs weather-station comparison.
struct WeatherStripView: View {
    let weather: WeatherSnapshot?
    let sensorDelta: Double?
    let units: UnitSystem
    let pressureMode: PressureDisplayMode
    let isMSLP: Bool
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("Local Conditions")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let weather {
                    HStack(spacing: 5) {
                        Image(systemName: WeatherCode.symbol(weather.weatherCode))
                            .symbolRenderingMode(.multicolor)
                        Text(WeatherCode.description(weather.weatherCode))
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                }
            }

            if let weather {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statTile(icon: "thermometer.medium", label: "Temp", value: units.temperature(weather.temperature))
                    statTile(icon: "thermometer.sun", label: "Feels", value: units.temperature(weather.apparentTemperature))
                    statTile(icon: "thermometer.snowflake", label: "Dew Pt", value: weather.dewPoint.map { units.temperature($0) } ?? "—")
                    statTile(icon: "wind", label: "Wind", value: units.speed(weather.windSpeed))
                    statTile(icon: "wind.snow", label: "Gusts", value: weather.windGust.map { units.speed($0) } ?? "—")
                    statTile(icon: "humidity.fill", label: "Humidity", value: "\(weather.humidity)%")
                    statTile(icon: "cloud.fill", label: "Cloud", value: weather.cloudCover.map { "\($0)%" } ?? "—")
                    statTile(icon: "umbrella.fill", label: "Rain 6h", value: weather.maxRainChance.map { "\($0)%" } ?? "—")
                    statTile(icon: "eye.fill", label: "Vis", value: weather.visibility.map { units.visibility($0) } ?? "—")
                    statTile(icon: "flame.fill", label: "CAPE", value: weather.cape.map { "\(Int($0)) J/kg" } ?? "—")
                    statTile(icon: "arrow.up.and.down.circle", label: "Lifted Idx", value: weather.liftedIndex.map { String(format: "%.1f", $0) } ?? "—")
                    statTile(icon: "building.columns", label: "Model", value: pressureMode.labeled(weather.stationPressure))
                }

                if let dewPoint = weather.dewPoint {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.cyan)
                        Text("Dew point \(units.temperature(dewPoint))")
                            .foregroundStyle(Theme.textSecondary)
                            + Text(dewPointNote(dewPoint))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .font(.system(size: 11, design: .rounded))
                    .padding(.top, 2)
                }

                if let cape = weather.cape {
                    HStack(spacing: 6) {
                        Image(systemName: capeSeverityIcon(cape))
                            .font(.system(size: 10))
                            .foregroundStyle(capeSeverityColor(cape))
                        Text("CAPE \(Int(cape)) J/kg: ")
                            .foregroundStyle(Theme.textSecondary)
                            + Text(capeSeverityLabel(cape))
                            .foregroundStyle(capeSeverityColor(cape))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 11, design: .rounded))
                }

                if let liftedIndex = weather.liftedIndex {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.and.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(stabilityColor(liftedIndex))
                        Text(String(format: "Lifted Index %.1f: ", liftedIndex))
                            .foregroundStyle(Theme.textSecondary)
                            + Text(stabilityLabel(liftedIndex))
                            .foregroundStyle(stabilityColor(liftedIndex))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 11, design: .rounded))
                }

                if let sensorDelta {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .foregroundStyle(Theme.cyan)
                        Text("Your sensor reads ")
                            .foregroundStyle(Theme.textSecondary)
                        + Text(pressureMode.delta(sensorDelta))
                            .foregroundStyle(Theme.cyan)
                            .fontWeight(.semibold)
                        + Text(" vs the weather model\(isMSLP ? " (both MSLP)" : "").")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.system(size: 12, design: .rounded))
                    .padding(.top, 2)
                }
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.cyan)
                    Text("Fetching local weather…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(Theme.orange)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Text("Waiting for location…")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
    }

    private func statTile(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.cyan)
                .frame(height: 18)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Dew point interpretation

    private func dewPointNote(_ dewPointC: Double) -> String {
        if dewPointC >= 21 { return " · Oppressive — very high storm potential" }
        if dewPointC >= 18 { return " · Muggy — storms possible" }
        if dewPointC >= 13 { return " · Comfortable" }
        if dewPointC >= 10 { return " · Pleasant" }
        return " · Dry"
    }

    // MARK: - Lifted Index interpretation

    private func stabilityLabel(_ liftedIndex: Double) -> String {
        if liftedIndex <= -6 { return "Very unstable — severe storms likely" }
        if liftedIndex <= -4 { return "Unstable — storms probable" }
        if liftedIndex <= -2 { return "Marginally unstable" }
        if liftedIndex <= 0 { return "Marginal" }
        return "Stable"
    }

    private func stabilityColor(_ liftedIndex: Double) -> Color {
        if liftedIndex <= -6 { return Theme.red }
        if liftedIndex <= -4 { return Theme.orange }
        if liftedIndex <= -2 { return Theme.amber }
        return Theme.green
    }

    // MARK: - CAPE interpretation

    private func capeSeverityLabel(_ cape: Double) -> String {
        if cape >= 4000 { return "Extreme instability" }
        if cape >= 2500 { return "Very unstable — severe storms likely" }
        if cape >= 1500 { return "Moderately unstable" }
        if cape >= 1000 { return "Marginally unstable" }
        if cape >= 500  { return "Low instability" }
        return "Stable"
    }

    private func capeSeverityColor(_ cape: Double) -> Color {
        if cape >= 4000 { return Theme.red }
        if cape >= 2500 { return Theme.orange }
        if cape >= 1000 { return Theme.amber }
        return Theme.green
    }

    private func capeSeverityIcon(_ cape: Double) -> String {
        if cape >= 2500 { return "flame.circle.fill" }
        if cape >= 1000 { return "flame.fill" }
        return "flame"
    }
}

#Preview {
    let sample = WeatherSnapshot(
        temperature: 28.5,
        apparentTemperature: 31.0,
        humidity: 65,
        windSpeed: 22.0,
        windGust: 45.0,
        dewPoint: 21.0,
        cloudCover: 75,
        visibility: 8000,
        cape: 2800,
        liftedIndex: -5.5,
        stationPressure: 1012.0,
        weatherCode: 3,
        maxRainChance: 40,
        fetchedAt: Date()
    )
    return ScrollView {
        VStack(spacing: 18) {
            WeatherStripView(
                weather: sample,
                sensorDelta: -1.5,
                units: .metric,
                pressureMode: .hPa,
                isMSLP: true,
                isLoading: false,
                errorMessage: nil
            )
        }
        .padding(16)
    }
    .background(Theme.ink)
    .preferredColorScheme(.dark)
}
