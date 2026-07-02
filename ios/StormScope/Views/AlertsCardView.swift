import SwiftUI

/// Active National Weather Service alerts for the user's exact location.
/// Tornado warnings are visually escalated above everything else.
struct AlertsCardView: View {
    let alerts: [NWSAlertFeature]
    let errorMessage: String?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                Text("NWS Alerts")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("api.weather.gov")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            if !alerts.isEmpty {
                VStack(spacing: 8) {
                    ForEach(alerts) { alert in
                        alertRow(alert)
                    }
                }
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.cyan)
                    Text("Checking official alerts…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(Theme.orange)
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Theme.green)
                    Text("No active NWS alerts for your area.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderColor, lineWidth: 1))
        .sensoryFeedback(.error, trigger: hasTornadoWarning)
    }

    private var hasTornadoWarning: Bool {
        alerts.contains { $0.isTornadoWarning }
    }

    private var borderColor: Color {
        hasTornadoWarning ? Theme.red.opacity(0.6) : Theme.panelStroke
    }

    private func alertRow(_ alert: NWSAlertFeature) -> some View {
        let tint = tint(for: alert)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.isTornadoRelated ? "tornado" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(alert.properties.event)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(alert.isTornadoWarning ? tint : Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if alert.isTornadoWarning {
                        Text("TAKE SHELTER")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .kerning(0.6)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.red.opacity(0.25))
                            .foregroundStyle(Theme.red)
                            .clipShape(Capsule())
                    }
                }
                if let area = alert.properties.areaDesc {
                    Text(area)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                }
                if let ends = alert.endTime {
                    Text("Until \(ends.formatted(date: .omitted, time: .shortened)) · ends \(ends.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(tint.opacity(alert.isTornadoWarning ? 0.14 : 0.07))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func tint(for alert: NWSAlertFeature) -> Color {
        if alert.isTornadoWarning { return Theme.red }
        switch alert.severityRank {
        case 4: return Theme.red
        case 3: return Theme.orange
        case 2: return Theme.amber
        default: return Theme.cyan
        }
    }
}
