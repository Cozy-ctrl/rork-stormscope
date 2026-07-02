import SwiftUI
import Charts

/// Pressure history over the last six hours as a smoothed area chart.
struct TrendChartView: View {
    let readings: [PressureReading]
    let tint: Color
    let pressureMode: PressureDisplayMode

    private var displayReadings: [PressureReading] {
        let cutoff = Date().addingTimeInterval(-6 * 3600)
        return readings.filter { $0.timestamp >= cutoff }
    }

    private var yDomain: ClosedRange<Double> {
        let values = displayReadings.map { pressureMode.value($0.hPa) }
        guard let minValue = values.min(), let maxValue = values.max() else {
            return pressureMode == .inHg ? 29.5...30.4 : 1000...1030
        }
        let minimumPadding = pressureMode == .inHg ? 0.03 : 1.0
        let padding = max((maxValue - minValue) * 0.2, minimumPadding)
        return (minValue - padding)...(maxValue + padding)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pressure · 6h")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(pressureMode.primaryUnit)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            if displayReadings.count < 2 {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textTertiary)
                    Text("Collecting readings — the trend line appears within minutes.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 160)
            } else {
                Chart(displayReadings) { reading in
                    AreaMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Pressure", pressureMode.value(reading.hPa))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [tint.opacity(0.35), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Pressure", pressureMode.value(reading.hPa))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: .dateTime.hour(), anchor: .top)
                            .foregroundStyle(Theme.textTertiary)
                            .font(.system(size: 10, design: .rounded))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel()
                            .foregroundStyle(Theme.textTertiary)
                            .font(.system(size: 10, design: .rounded))
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
    }
}
