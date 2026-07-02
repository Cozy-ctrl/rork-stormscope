import SwiftUI

/// The nearest NWS observation stations with their latest real measured
/// pressure, temperature, dew point, wind, visibility, and precipitation —
/// compared against the device barometer.
struct StationsCardView: View {
    let stations: [StationObservation]
    let devicePressure: Double?
    let units: UnitSystem
    let pressureMode: PressureDisplayMode
    let isLoading: Bool
    let errorMessage: String?
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !isExpanded {
                EmptyView()
            } else if !stations.isEmpty {
                VStack(spacing: 8) {
                    ForEach(stations) { station in
                        stationRow(station)
                    }
                }
                Text("Real instrument readings from official stations — your sensor updates continuously, stations report about once an hour.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.cyan)
                    Text("Finding nearby stations…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Header

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sensor.tag.radiowaves.forward")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.cyan)
                Text("Nearest NWS Stations")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !stations.isEmpty {
                    Text("\(stations.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse station list" : "Expand station list")
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    // MARK: - Rows

    private func stationRow(_ station: StationObservation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: ID + name + distance
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(station.id)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        Text(units.distance(station.distanceKm))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.cyan.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    Text(station.name)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                    if let observedAt = station.observedAt {
                        Text(observedAt.formatted(.relative(presentation: .named)))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.textTertiary.opacity(0.8))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let pressure = station.pressureHPa {
                        Text(pressureMode.labeled(pressure))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                        if let devicePressure {
                            deltaLabel(device: devicePressure, station: pressure)
                        }
                    } else {
                        Text("No pressure")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            // Detail chips: temperature, dew point, wind, humidity, visibility, precip
            HStack(spacing: 6) {
                if let temp = station.temperatureC {
                    detailChip(icon: "thermometer.medium", text: units.temperature(temp))
                }
                if let dew = station.dewPointC {
                    detailChip(icon: "drop.fill", text: units.temperature(dew), tint: Theme.cyan)
                }
                if let wind = station.windSpeedKmh {
                    let label: String = {
                        if let dir = station.windDirectionDeg {
                            return "\(windDirArrow(dir)) \(units.speed(wind))"
                        }
                        return units.speed(wind)
                    }()
                    detailChip(icon: "wind", text: label)
                }
                if let gust = station.windGustKmh {
                    detailChip(icon: "wind.snow", text: "G \(units.speed(gust))")
                }
                if let hum = station.humidity {
                    detailChip(icon: "humidity.fill", text: "\(hum)%")
                }
                if let vis = station.visibilityM {
                    detailChip(icon: "eye.fill", text: units.visibility(vis))
                }
                if let precip = station.precipLastHourMm {
                    detailChip(icon: "drop.circle.fill", text: String(format: "%.1f mm", precip))
                }
            }

            if let conditions = station.conditions, !conditions.isEmpty {
                Text(conditions)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Chips

    private func detailChip(icon: String, text: String, tint: Color = Theme.textSecondary) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(tint)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(tint.opacity(0.08))
        .clipShape(Capsule())
    }

    private func deltaLabel(device: Double, station: Double) -> some View {
        let delta = device - station
        return HStack(spacing: 3) {
            Image(systemName: "scope")
                .font(.system(size: 8))
            Text("\(pressureMode.delta(delta)) you")
                .monospacedDigit()
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(abs(delta) > 4 ? Theme.amber : Theme.cyan)
    }

    private func windDirArrow(_ degrees: Double) -> String {
        switch degrees {
        case 0..<22.5, 337.5...: return "N"
        case 22.5..<67.5:       return "NE"
        case 67.5..<112.5:      return "E"
        case 112.5..<157.5:     return "SE"
        case 157.5..<202.5:     return "S"
        case 202.5..<247.5:     return "SW"
        case 247.5..<292.5:     return "W"
        case 292.5..<337.5:     return "NW"
        default:                return ""
        }
    }
}
