import SwiftUI

/// Real-time lightning proximity card driven by the device magnetometer.
///
/// When the magnetometer is present, the card shows:
/// - A live ambient field strength readout
/// - Count and time-since-last detected spike
/// - Visual proximity indicator (color ring + label)
/// - Recent strike timeline
/// - Suppression notice when the device is being handled
///
/// Without a magnetometer, the card shows a graceful disabled state
/// explaining that the feature is unavailable on this device.
///
/// Detection is intentionally conservative: real lightning EMP is a
/// sub-second spike, not a sustained deviation. Phone movement, nearby
/// electronics, and ambient field changes are filtered out.
struct LightningCardView: View {
    let magnetometer: MagnetometerService

    @State private var ringPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if magnetometer.isUnavailable {
                unavailableState
            } else if !magnetometer.isRunning {
                idleState
            } else if magnetometer.isSuppressed {
                suppressedState
            } else {
                liveState
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(proximityTint.opacity(0.3), lineWidth: 1)
        )
        .onChange(of: magnetometer.lastStrike?.timestamp) { _, _ in
            ringPulse = true
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                ringPulse = false
            }
        }
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: magnetometer.lastStrike?.timestamp)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(proximityTint)
                .symbolEffect(.variableColor.iterative, isActive: magnetometer.isRunning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Lightning Proximity")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("On-device magnetometer · EMP detection")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()

            if magnetometer.isRunning {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .stroke(Theme.green.opacity(0.4), lineWidth: 2)
                            .scaleEffect(ringPulse ? 2.0 : 1.0)
                            .opacity(ringPulse ? 0 : 0.5)
                            .animation(.easeOut(duration: 0.6), value: ringPulse)
                    )
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(Theme.green)
            }
        }
    }

    // MARK: - Unavailable state

    private var unavailableState: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.textTertiary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Magnetometer unavailable")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("This device lacks a magnetometer or it is not accessible. Lightning detection requires the compass sensor, which is present on most iPhones since the 3GS. Try on another device or check your privacy settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Idle state

    private var idleState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Theme.cyan)
                .scaleEffect(0.8)
            Text("Starting magnetometer stream…")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Suppressed state

    /// Shown when the detector is gated because the device is moving.
    /// Movement produces field changes that swamp the lightning signal.
    private var suppressedState: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("Detector paused")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("Keep the device still for accurate lightning detection. Movement creates magnetic fluctuations that look like false strikes.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Theme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Live state

    private var liveState: some View {
        VStack(spacing: 12) {
            proximityRing

            HStack(spacing: 8) {
                metricTile(
                    icon: "bolt.fill",
                    label: "Detected",
                    value: "\(magnetometer.strikeCount)",
                    tint: proximityTint
                )
                metricTile(
                    icon: "clock",
                    label: "Last",
                    value: lastStrikeTime,
                    tint: Theme.textSecondary
                )
                metricTile(
                    icon: "location",
                    label: "Est. Distance",
                    value: distanceEstimate,
                    tint: proximityTint
                )
            }

            if !magnetometer.recentStrikes.isEmpty {
                recentStrikesTimeline
            }

            if magnetometer.strikeCount == 0 {
                noDetectionsHint
            } else {
                Text("The magnetometer detects the electromagnetic pulse (EMP) of close-range lightning — strikes within roughly 4 km. Counts cover the last hour; distance is a rough estimate that varies with strike current and device orientation.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Proximity ring

    private var proximityRing: some View {
        ZStack {
            Circle()
                .stroke(proximityTint.opacity(0.15), lineWidth: 8)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: ringPulse ? 0.85 : 0.3)
                .stroke(
                    AngularGradient(
                        colors: [proximityTint, proximityTint.opacity(0.3)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: ringPulse)

            VStack(spacing: 2) {
                Text(proximityTitle)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(proximityTint)
                if let field = magnetometer.latestTotalField {
                    Text(String(format: "%.0f µT", field))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline

    private var recentStrikesTimeline: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent Detections")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)

            ForEach(Array(magnetometer.recentStrikes.suffix(10).reversed().enumerated()), id: \.offset) { _, strike in
                HStack(spacing: 8) {
                    Circle()
                        .fill(strike.proximity.tint == "red" ? Theme.red :
                              strike.proximity.tint == "orange" ? Theme.orange :
                              strike.proximity.tint == "amber" ? Theme.amber : Theme.green)
                        .frame(width: 6, height: 6)
                    Text(strike.timestamp.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                    Spacer()
                    Text(String(format: "%+.1f µT", strike.peakDeviation))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                    Text(String(format: "~%.0f km", strike.estimatedDistanceKm))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - No-detection hint

    private var noDetectionsHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("No strikes detected")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Text("The detector is live and listening. Keep the device still — lightning detection is conservative to avoid false alarms from movement or electronics.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Theme.green.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var proximityTitle: String {
        switch magnetometer.proximityLabel {
        case .none:       return "Listening"
        case .veryClose:  return "VERY CLOSE"
        case .nearby:     return "Nearby"
        case .distant:    return "Distant"
        case .far:        return "Far"
        }
    }

    private var proximityTint: Color {
        switch magnetometer.proximityLabel {
        case .none:       return Theme.textSecondary
        case .veryClose:  return Theme.red
        case .nearby:     return Theme.orange
        case .distant:    return Theme.amber
        case .far:        return Theme.green
        }
    }

    private var lastStrikeTime: String {
        guard let seconds = magnetometer.secondsSinceLastStrike else { return "—" }
        if seconds < 60 {
            return String(format: "%.0fs ago", seconds)
        } else if seconds < 3600 {
            return String(format: "%.0fm ago", seconds / 60)
        }
        return ">1h ago"
    }

    private var distanceEstimate: String {
        guard let km = magnetometer.estimatedDistanceKm else { return "—" }
        if km < 1 {
            return String(format: "%.0fm", km * 1000)
        } else {
            return String(format: "%.0f km", km)
        }
    }

    private func metricTile(icon: String, label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .frame(height: 16)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    let service = MagnetometerService()
    return ScrollView {
        VStack(spacing: 18) {
            LightningCardView(magnetometer: service)
        }
        .padding(16)
    }
    .background(Theme.ink)
    .preferredColorScheme(.dark)
}
