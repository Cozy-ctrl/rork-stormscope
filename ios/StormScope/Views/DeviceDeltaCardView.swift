import SwiftUI
import Charts

/// A diverging bar chart centered on the device barometer (zero line) showing
/// each nearby station's signed pressure offset. Bars on both sides indicate a
/// real spatial gradient; bars all on one side indicate calibration/altitude
/// drift. A computed gradient arrow shows where pressure is falling toward.
struct DeviceDeltaCardView: View {
    let stations: [StationObservation]
    let devicePressure: Double
    let deviceLatitude: Double?
    let deviceLongitude: Double?
    let pressureMode: PressureDisplayMode

    private struct DeltaPoint: Identifiable {
        let id: String
        let shortID: String
        let distanceKm: Double
        /// Station minus device, in hPa.
        let deltaHPa: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "plusminus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.cyan)
                Text("You vs Stations")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if let worst = points.map({ abs($0.deltaHPa) }).max() {
                    agreementBadge(maxAbsDelta: worst)
                }
            }

            if points.count >= 2 {
                chart

                if let gradient = pressureGradient, gradient.isSignificant {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber)
                            .rotationEffect(.degrees(gradient.towardLowBearingDeg))
                        Text(String(
                            format: "Pressure is falling toward the %@ (%.1f hPa per 100 km) — systems generally approach from the falling side.",
                            gradient.compassLabel,
                            gradient.magnitudeHPaPer100km
                        ))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(verdictText)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not enough station pressure reports to compare against your sensor yet.")
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

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Offset", displayDelta(point.deltaHPa)),
                    y: .value("Station", point.shortID),
                    height: .fixed(16)
                )
                .foregroundStyle(barColor(point).gradient)
                .clipShape(.rect(cornerRadius: 3))
                .annotation(position: point.deltaHPa >= 0 ? .trailing : .leading, spacing: 4) {
                    Text(formattedDelta(point.deltaHPa))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(barColor(point))
                }
            }

            RuleMark(x: .value("You", 0))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .foregroundStyle(Theme.cyan.opacity(0.85))
                .annotation(position: .top, alignment: .center) {
                    Text("YOU")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(Theme.cyan)
                }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel()
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let id = value.as(String.self) {
                        Text(id)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .frame(height: CGFloat(points.count) * 32 + 34)
        .clipped()
    }

    // MARK: - Data

    /// Stations reporting pressure, nearest first, with signed hPa offsets.
    private var points: [DeltaPoint] {
        stations
            .compactMap { station -> DeltaPoint? in
                guard let pressure = station.pressureHPa else { return nil }
                let short = station.id.hasPrefix("K") ? String(station.id.dropFirst()) : station.id
                return DeltaPoint(
                    id: station.id,
                    shortID: short,
                    distanceKm: station.distanceKm,
                    deltaHPa: pressure - devicePressure
                )
            }
            .sorted { $0.distanceKm < $1.distanceKm }
    }

    private var pressureGradient: PressureGradient? {
        guard let lat = deviceLatitude, let lon = deviceLongitude else { return nil }
        return PressureGradient.compute(
            stations: stations,
            deviceLatitude: lat,
            deviceLongitude: lon,
            devicePressure: devicePressure
        )
    }

    /// Symmetric x-domain so the zero "You" line stays centered.
    private var xDomain: ClosedRange<Double> {
        let maxAbs = points.map { abs(displayDelta($0.deltaHPa)) }.max() ?? 1
        let floor = pressureMode == .inHg ? 0.05 : 1.5
        let limit = max(maxAbs * 1.45, floor)
        return -limit...limit
    }

    private func displayDelta(_ deltaHPa: Double) -> Double {
        pressureMode == .inHg ? deltaHPa * 0.02953 : deltaHPa
    }

    private func formattedDelta(_ deltaHPa: Double) -> String {
        pressureMode == .inHg
            ? String(format: "%+.2f", deltaHPa * 0.02953)
            : String(format: "%+.1f", deltaHPa)
    }

    /// Same agreement scale as the station map pins.
    private func barColor(_ point: DeltaPoint) -> Color {
        let magnitude = abs(point.deltaHPa)
        if magnitude < 1.5 { return Theme.green }
        if magnitude < 4 { return Theme.amber }
        return Theme.orange
    }

    private func agreementBadge(maxAbsDelta: Double) -> some View {
        let (label, color): (String, Color) = {
            if maxAbsDelta < 1.5 { return ("VERIFIED", Theme.green) }
            if maxAbsDelta < 4 { return ("DRIFTING", Theme.amber) }
            return ("DIVERGENT", Theme.orange)
        }()
        return Text(label)
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .kerning(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    /// Interprets the delta pattern: agreement, one-sided drift, or a real gradient.
    private var verdictText: String {
        let deltas = points.map(\.deltaHPa)
        guard let maxAbs = deltas.map({ abs($0) }).max() else { return "" }

        if maxAbs < 1.5 {
            return "Every station is within ±1.5 hPa of your sensor — your barometer is verified against the official network."
        }
        let allHigher = deltas.allSatisfy { $0 > 0 }
        let allLower = deltas.allSatisfy { $0 < 0 }
        if (allHigher || allLower), maxAbs >= 2 {
            return "All stations read \(allHigher ? "higher" : "lower") than you by a similar amount — this usually means altitude or sensor offset, not weather. Tap Calibrate in Settings to align."
        }
        if maxAbs >= 4 {
            return "Stations disagree with your sensor in different directions — a real pressure gradient is crossing the area. Watch the tendency cards for movement."
        }
        return "Mild spread against nearby stations — normal mesoscale variation. Bars split on both sides of the You line indicate a genuine local gradient."
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        DeviceDeltaCardView(
            stations: [
                StationObservation(
                    id: "KSFO", name: "San Francisco Intl Airport",
                    latitude: 37.619, longitude: -122.375, distanceKm: 5.2,
                    pressureHPa: 1013.2, temperatureC: 18.5, dewPointC: 12.1,
                    windSpeedKmh: 22, windGustKmh: nil, windDirectionDeg: 280,
                    humidity: 67, visibilityM: 16000, precipLastHourMm: nil,
                    conditions: "Partly Cloudy", observedAt: Date()
                ),
                StationObservation(
                    id: "KOAK", name: "Oakland Metro Airport",
                    latitude: 37.721, longitude: -122.221, distanceKm: 18.7,
                    pressureHPa: 1009.1, temperatureC: 17.2, dewPointC: 13.5,
                    windSpeedKmh: 15, windGustKmh: nil, windDirectionDeg: 250,
                    humidity: 78, visibilityM: 12000, precipLastHourMm: 0.2,
                    conditions: "Mostly Cloudy", observedAt: Date()
                ),
                StationObservation(
                    id: "KNUQ", name: "Moffett Federal Airfield",
                    latitude: 37.416, longitude: -122.049, distanceKm: 28.3,
                    pressureHPa: 1015.8, temperatureC: 20.1, dewPointC: 10.8,
                    windSpeedKmh: 10, windGustKmh: nil, windDirectionDeg: 310,
                    humidity: 55, visibilityM: 16000, precipLastHourMm: nil,
                    conditions: "Clear", observedAt: Date()
                ),
            ],
            devicePressure: 1012.5,
            deviceLatitude: 37.52,
            deviceLongitude: -122.25,
            pressureMode: .hPa
        )
        .padding()
    }
}
