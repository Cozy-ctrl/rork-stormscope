import SwiftUI

/// First-launch safety disclaimer shown once before the main dashboard.
/// The user must acknowledge it before using the app.
struct DisclaimerSheet: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 28)

                Text("Important Safety Notice")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.bottom, 20)

            // Advisory text
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    advisoryRow(
                        icon: "sparkles",
                        color: Theme.cyan,
                        text: "StormScope uses your iPhone's barometer to detect rapid pressure changes that often precede severe weather. It is a supplemental tool only."
                    )

                    advisoryRow(
                        icon: "antenna.radiowaves.left.and.right",
                        color: Theme.amber,
                        text: "Pressure data is collected from a single point — your device — and cannot confirm tornadoes, hail, or specific hazard types on its own."
                    )

                    advisoryRow(
                        icon: "bell.badge.fill",
                        color: Theme.red,
                        text: "Always rely on official sources for life-safety decisions: NOAA Weather Radio, local NWS alerts, emergency broadcasts, and civil authority instructions."
                    )

                    advisoryRow(
                        icon: "location.fill.viewfinder",
                        color: Theme.green,
                        text: "StormScope integrates NWS alerts, SPC outlooks, and station observations as additional data points, but weather can change faster than any app can refresh."
                    )
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 320)

            Spacer(minLength: 0)

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onAccept) {
                    Text("I Understand — Continue")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.amber, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("I understand and wish to continue")

                Text("You can review this information anytime in the Info panel.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 36)
        .background(Theme.ink)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(true)
    }

    private func advisoryRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        DisclaimerSheet(onAccept: { print("Accepted") })
    }
}
