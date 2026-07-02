import SwiftUI

/// Compact one-line NWS alert summary shown above the radar map. Tapping it
/// opens the full alert list; tornado warnings escalate the styling.
struct AlertsStripView: View {
    let alerts: [NWSAlertFeature]
    let errorMessage: String?
    let isLoading: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(hasTornadoWarning ? Theme.red : Theme.textPrimary)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isLoading && alerts.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.cyan)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(hasTornadoWarning ? Theme.red.opacity(0.14) : Theme.panel)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(hasTornadoWarning ? Theme.red.opacity(0.6) : Theme.panelStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.error, trigger: hasTornadoWarning)
        .accessibilityLabel(title)
        .accessibilityHint("Opens the full alert list")
    }

    private var hasTornadoWarning: Bool {
        alerts.contains { $0.isTornadoWarning }
    }

    private var icon: String {
        if hasTornadoWarning { return "tornado" }
        if !alerts.isEmpty { return "exclamationmark.triangle.fill" }
        if errorMessage != nil { return "wifi.exclamationmark" }
        return "checkmark.shield.fill"
    }

    private var tint: Color {
        if hasTornadoWarning { return Theme.red }
        if !alerts.isEmpty { return Theme.orange }
        if errorMessage != nil { return Theme.orange }
        return Theme.green
    }

    private var title: String {
        if hasTornadoWarning { return "TORNADO WARNING — TAKE SHELTER" }
        if alerts.count == 1 { return alerts[0].properties.event }
        if alerts.count > 1 { return "\(alerts.count) active NWS alerts" }
        if let errorMessage { return errorMessage }
        return "No active NWS alerts"
    }

    private var subtitle: String? {
        if alerts.count > 1 {
            return alerts.prefix(2).map { $0.properties.event }.joined(separator: " · ")
        }
        if alerts.count == 1, let area = alerts[0].properties.areaDesc {
            return area
        }
        if alerts.isEmpty && errorMessage == nil {
            return "api.weather.gov · tap for details"
        }
        return nil
    }
}
