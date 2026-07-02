import SwiftUI

/// Shown only while an extreme pressure event is being cross-validated
/// against nearby NWS stations. Displays the rapid-polling status, the
/// verdict, and each station's hour-over-hour pressure trend.
struct EventConfirmationCardView: View {
    let confirmation: EventConfirmation?
    let isChecking: Bool
    let pressureMode: PressureDisplayMode
    let onCheckNow: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let confirmation {
                verdictRow(confirmation)
                if !confirmation.trends.isEmpty {
                    Divider().overlay(Theme.panelStroke)
                    VStack(spacing: 8) {
                        ForEach(confirmation.trends) { trend in
                            stationRow(trend)
                        }
                    }
                }
                footer(confirmation)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.amber)
                    Text("Polling nearby NWS stations for confirmation…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(verdictTint.opacity(0.35), lineWidth: 1)
        )
        .onAppear { isPulsing = true }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Theme.red)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.25 : 1)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            Text("SIGNAL CONFIRMATION")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .kerning(1.2)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Button {
                onCheckNow()
            } label: {
                HStack(spacing: 4) {
                    if isChecking {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Theme.cyan)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(isChecking ? "Checking" : "Check now")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.cyan.opacity(0.12))
                .clipShape(Capsule())
            }
            .disabled(isChecking)
        }
    }

    private func verdictRow(_ confirmation: EventConfirmation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verdictIcon(confirmation.verdict))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(verdictTint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(confirmation.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(verdictTint)
                Text(confirmation.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stationRow(_ trend: StationPressureTrend) -> some View {
        HStack(spacing: 8) {
            Image(systemName: trendIcon(trend))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(trendColor(trend))
                .frame(width: 16)
            Text(trend.id)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
            Text(String(format: "%.0f km", trend.distanceKm))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let delta = trend.deltaHPa {
                Text("\(pressureMode.delta(delta))/h")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(trendColor(trend))
            } else {
                Text("no recent trend")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private func footer(_ confirmation: EventConfirmation) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 10))
            Text("Rapid polling active — rechecking every 5 min. Last check \(confirmation.checkedAt.formatted(date: .omitted, time: .shortened)). Stations issue special reports during rapid pressure changes.")
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(Theme.textTertiary)
    }

    // MARK: - Styling helpers

    private var verdictTint: Color {
        switch confirmation?.verdict {
        case .confirmed: return Theme.red
        case .partial: return Theme.orange
        case .notConfirmed: return Theme.cyan
        case .insufficientData, nil: return Theme.amber
        }
    }

    private func verdictIcon(_ verdict: EventConfirmation.Verdict) -> String {
        switch verdict {
        case .confirmed: return "checkmark.seal.fill"
        case .partial: return "exclamationmark.triangle.fill"
        case .notConfirmed: return "scope"
        case .insufficientData: return "antenna.radiowaves.left.and.right"
        }
    }

    private func trendIcon(_ trend: StationPressureTrend) -> String {
        guard let delta = trend.deltaHPa else { return "minus.circle" }
        if trend.isFalling { return "arrow.down.circle.fill" }
        return delta >= 0.5 ? "arrow.up.circle" : "equal.circle"
    }

    private func trendColor(_ trend: StationPressureTrend) -> Color {
        guard trend.deltaHPa != nil else { return Theme.textTertiary }
        return trend.isFalling ? Theme.red : Theme.green
    }
}
