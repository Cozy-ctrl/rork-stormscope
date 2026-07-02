import SwiftUI

/// A circular aneroid-style barometer gauge with colored risk zones,
/// tick marks, and an animated needle. Supports dual-unit display (hPa + inHg)
/// when the user selects that mode.
struct PressureGaugeView: View {
    let pressure: Double?
    let level: StormLevel
    let ratePerHour: Double?
    let pressureMode: PressureDisplayMode
    var isCalibrated: Bool = false
    var isMSLP: Bool = false

    /// hPa range the gauge dial covers (same regardless of display unit).
    private let minPressure: Double = 970
    private let maxPressure: Double = 1050
    private let sweepDegrees: Double = 270

    var body: some View {
        ZStack {
            zoneArcs
            ticks
            scaleLabels
            needle
            hub
            readout
        }
        .frame(width: 300, height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Geometry

    private func fraction(for value: Double) -> Double {
        let clamped = min(max(value, minPressure), maxPressure)
        return (clamped - minPressure) / (maxPressure - minPressure)
    }

    /// Angle in degrees where 0° points up; gauge sweeps -135°…+135°.
    /// Always uses hPa for the dial position.
    private func angle(for hPa: Double) -> Double {
        -sweepDegrees / 2 + fraction(for: hPa) * sweepDegrees
    }

    // MARK: - Layers

    private var zoneArcs: some View {
        ZStack {
            arc(from: minPressure, to: 995, color: Theme.red.opacity(0.75))
            arc(from: 995, to: 1009, color: Theme.amber.opacity(0.75))
            arc(from: 1009, to: 1025, color: Theme.green.opacity(0.6))
            arc(from: 1025, to: maxPressure, color: Theme.cyan.opacity(0.6))
        }
    }

    private func arc(from start: Double, to end: Double, color: Color) -> some View {
        Circle()
            .trim(from: 0.375 + fraction(for: start) * 0.75, to: 0.375 + fraction(for: end) * 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
            .rotationEffect(.degrees(90))
            .padding(10)
    }

    private var ticks: some View {
        ForEach(Array(stride(from: minPressure, through: maxPressure, by: 5)), id: \.self) { value in
            let isMajor = value.truncatingRemainder(dividingBy: 20) == 0
            Rectangle()
                .fill(isMajor ? Theme.textPrimary.opacity(0.85) : Theme.textTertiary)
                .frame(width: isMajor ? 2.5 : 1.2, height: isMajor ? 14 : 7)
                .offset(y: -122)
                .rotationEffect(.degrees(angle(for: value)))
        }
    }

    private var scaleLabels: some View {
        ForEach(Array(stride(from: minPressure, through: maxPressure, by: 20)), id: \.self) { value in
            let radians = angle(for: value) * .pi / 180
            Text(pressureMode.gaugeLabel(value))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .offset(x: sin(radians) * 100, y: -cos(radians) * 100)
        }
    }

    private var needle: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [Theme.amber, Theme.amber.opacity(0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 4, height: 96)
            .offset(y: -48)
            .rotationEffect(.degrees(angle(for: pressure ?? 1013)))
            .shadow(color: Theme.amber.opacity(0.45), radius: 6)
            .animation(.spring(response: 1.1, dampingFraction: 0.75), value: pressure)
            .opacity(pressure == nil ? 0.25 : 1)
    }

    private var hub: some View {
        Circle()
            .fill(Theme.panel)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(Theme.amber.opacity(0.8), lineWidth: 2))
    }

    private var readout: some View {
        VStack(spacing: 2) {
            if let pressure {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(pressureMode.primaryString(pressure))
                        .font(.system(size: pressureMode == .dual ? 36 : 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.default, value: pressure)
                    if isCalibrated {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.green)
                            .padding(.top, pressureMode == .dual ? 4 : 8)
                            .accessibilityLabel("Calibrated to nearest NWS station")
                    }
                }
            } else {
                Text("——")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 5) {
                if isMSLP {
                    Text("MSLP")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .kerning(1)
                        .foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(pressureMode.primaryUnit)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .kerning(2)
            }

            if pressureMode == .dual, let pressure {
                Text(String(format: "%.2f inHg", pressure * 0.029529983))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
                    .monospacedDigit()
                    .padding(.top, 1)
            }

            if let ratePerHour {
                HStack(spacing: 4) {
                    Image(systemName: ratePerHour < -0.3 ? "arrow.down.right" : ratePerHour > 0.3 ? "arrow.up.right" : "arrow.right")
                    Text(pressureMode.rate(ratePerHour))
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(level.tint)
                .padding(.top, 4)
            }
        }
        .offset(y: 76)
    }

    private var accessibilityText: String {
        guard let pressure else { return "Barometer initializing" }
        var text = "Pressure \(isMSLP ? "mean sea level " : "")\(pressureMode.primaryString(pressure)) \(pressureMode.primaryUnit)"
        if pressureMode == .dual {
            text += ", \(String(format: "%.2f inHg", pressure * 0.029529983))"
        }
        if isCalibrated { text += ", calibrated" }
        if let ratePerHour {
            text += ", changing \(pressureMode.rate(ratePerHour))"
        }
        return text
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        VStack(spacing: 40) {
            PressureGaugeView(pressure: 1013.2, level: .falling, ratePerHour: -1.2, pressureMode: .hPa, isMSLP: true)
            PressureGaugeView(pressure: 1013.2, level: .falling, ratePerHour: -1.2, pressureMode: .dual)
        }
    }
}
