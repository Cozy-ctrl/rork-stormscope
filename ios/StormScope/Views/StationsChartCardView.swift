import SwiftUI
import Charts

/// The measurable quantities that can be compared across nearby stations.
enum StationMetric: String, CaseIterable, Identifiable {
    case pressure
    case temperature
    case dewPoint
    case wind
    case humidity

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pressure:    return "Pressure"
        case .temperature: return "Temp"
        case .dewPoint:    return "Dew Pt"
        case .wind:        return "Wind"
        case .humidity:    return "Humidity"
        }
    }

    var icon: String {
        switch self {
        case .pressure:    return "gauge.medium"
        case .temperature: return "thermometer.medium"
        case .dewPoint:    return "drop.fill"
        case .wind:        return "wind"
        case .humidity:    return "humidity.fill"
        }
    }

    /// Why this comparison matters — shown under the chart.
    var insight: String {
        switch self {
        case .pressure:
            return "A pressure fall from one side of the map to the other marks an approaching front — the steeper the slope, the stronger the system."
        case .temperature:
            return "A sharp temperature difference between nearby stations often marks a frontal boundary or outflow from a storm."
        case .dewPoint:
            return "Higher dew points mean more storm fuel. A dry-line (sharp dew point gradient) is a classic severe-storm trigger zone."
        case .wind:
            return "Winds that differ strongly between stations suggest convergence — where air piles up and is forced to rise, storms can fire."
        case .humidity:
            return "Moist air near saturation feeds cloud growth; a moisture gradient shows where storm fuel is concentrated."
        }
    }
}

/// An interactive bar chart comparing a chosen measurement across the nearby
/// NWS stations (ordered by distance), with the device reading as a rule line
/// where comparable. Tapping a bar highlights that station's exact value.
struct StationsChartCardView: View {
    let stations: [StationObservation]
    let devicePressure: Double?
    let units: UnitSystem
    let pressureMode: PressureDisplayMode
    @State private var metric: StationMetric = .pressure
    @State private var selectedStationID: String?

    private struct DataPoint: Identifiable {
        let id: String
        let distanceKm: Double
        let value: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.cyan)
                Text("Station Comparison")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }

            metricPicker

            if dataPoints.count >= 2 {
                chart
                if let insight = gradientCallout {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber)
                        Text(insight)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(metric.insight)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not enough station data to compare \(metric.label.lowercased()) yet.")
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

    // MARK: - Pieces

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(StationMetric.allCases) { candidate in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            metric = candidate
                            selectedStationID = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: candidate.icon)
                                .font(.system(size: 9))
                            Text(candidate.label)
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(metric == candidate ? Theme.ink : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(metric == candidate ? Theme.cyan : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: metric)
    }

    private var chart: some View {
        Chart {
            ForEach(sortedPoints) { point in
                BarMark(
                    x: .value("Station", point.id),
                    y: .value(metric.label, point.value)
                )
                .foregroundStyle(
                    point.id == selectedStationID
                        ? Theme.amber.gradient
                        : Theme.cyan.gradient
                )
                .clipShape(.rect(cornerRadius: 4))
                .annotation(position: .top, spacing: 4) {
                    if point.id == selectedStationID {
                        Text(formattedValue(point.value))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Theme.amber)
                    }
                }
            }

            if metric == .pressure, let devicePressure {
                RuleMark(y: .value("You", displayValue(devicePressure)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Theme.green.opacity(0.8))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("You")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.green)
                    }
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let id = value.as(String.self) {
                        Text(id.hasPrefix("K") ? String(id.dropFirst()) : id)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel()
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .chartXSelection(value: Binding<String?>(
            get: { selectedStationID },
            set: { selectedStationID = $0 }
        ))
        .frame(height: 170)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: metric)
        .sensoryFeedback(.selection, trigger: selectedStationID)
    }

    // MARK: - Data

    /// The stations that have a value for the current metric, nearest first.
    private var dataPoints: [DataPoint] {
        stations.compactMap { station in
            guard let raw = rawValue(for: station) else { return nil }
            return DataPoint(id: station.id, distanceKm: station.distanceKm, value: displayValue(raw))
        }
    }

    private var sortedPoints: [DataPoint] {
        dataPoints.sorted { $0.distanceKm < $1.distanceKm }
    }

    private func rawValue(for station: StationObservation) -> Double? {
        switch metric {
        case .pressure:    return station.pressureHPa
        case .temperature: return station.temperatureC
        case .dewPoint:    return station.dewPointC
        case .wind:        return station.windSpeedKmh
        case .humidity:    return station.humidity.map(Double.init)
        }
    }

    /// Converts a raw metric value into the user's display unit.
    private func displayValue(_ raw: Double) -> Double {
        switch metric {
        case .pressure:
            return pressureMode == .inHg ? raw * 0.02953 : raw
        case .temperature, .dewPoint:
            return units == .imperial ? raw * 9 / 5 + 32 : raw
        case .wind:
            return units == .imperial ? raw * 0.621371 : raw
        case .humidity:
            return raw
        }
    }

    private func formattedValue(_ value: Double) -> String {
        switch metric {
        case .pressure:
            return pressureMode == .inHg
                ? String(format: "%.2f inHg", value)
                : String(format: "%.1f hPa", value)
        case .temperature, .dewPoint:
            return String(format: "%.0f°%@", value, units == .imperial ? "F" : "C")
        case .wind:
            return String(format: "%.0f %@", value, units == .imperial ? "mph" : "km/h")
        case .humidity:
            return String(format: "%.0f%%", value)
        }
    }

    /// A y-domain padded around the data so small gradients remain visible.
    private var yDomain: ClosedRange<Double> {
        let values = dataPoints.map(\.value)
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        let spread = max(maxV - minV, metric == .pressure ? (pressureMode == .inHg ? 0.1 : 2) : 4)
        let pad = spread * 0.25
        let lower = metric == .humidity ? max(0, minV - pad) : minV - pad
        let upper = metric == .humidity ? min(100, maxV + pad) : maxV + pad
        return lower...max(upper, lower + 0.001)
    }

    /// Calls out a notable spread across stations for the current metric.
    private var gradientCallout: String? {
        let values = dataPoints.map(\.value)
        guard values.count >= 2, let minV = values.min(), let maxV = values.max() else { return nil }
        let spread = maxV - minV
        switch metric {
        case .pressure:
            let spreadHPa = pressureMode == .inHg ? spread / 0.02953 : spread
            if spreadHPa > 6 { return "Strong pressure gradient across stations — possible approaching front." }
            if spreadHPa > 3 { return "Moderate pressure gradient — watch for wind shifts." }
        case .dewPoint:
            let spreadC = units == .imperial ? spread * 5 / 9 : spread
            if spreadC > 6 { return "Sharp moisture gradient — a dry-line-like boundary may be nearby." }
        case .temperature:
            let spreadC = units == .imperial ? spread * 5 / 9 : spread
            if spreadC > 6 { return "Sharp temperature contrast — a frontal boundary or storm outflow may be present." }
        case .wind:
            let spreadKmh = units == .imperial ? spread / 0.621371 : spread
            if spreadKmh > 25 { return "Large wind speed differences — possible convergence zone." }
        case .humidity:
            if spread > 30 { return "Strong humidity contrast across the area." }
        }
        return nil
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        StationsChartCardView(
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
            units: .metric,
            pressureMode: .hPa
        )
        .padding()
    }
}
