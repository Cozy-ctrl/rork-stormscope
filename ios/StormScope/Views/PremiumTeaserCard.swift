import SwiftUI

/// Dimmed teaser card shown in place of a gated feature while it is locked.
/// Keeps roughly the same visual footprint as the real card (no layout
/// jumping when the trial ends); tapping anywhere opens the paywall.
struct PremiumTeaserCard: View {
    let icon: String
    let title: String
    let message: String
    var tint: Color = Theme.cyan
    var minHeight: CGFloat = 150
    let onUnlock: () -> Void

    private let accentGradient = LinearGradient(
        colors: [Theme.cyan, Color(red: 0.65, green: 0.55, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Button(action: onUnlock) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accentGradient)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    lockPill
                }

                Spacer(minLength: 8)

                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text("Tap to unlock with StormScope Pro")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Theme.panel.opacity(0.6))
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(accentGradient.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), locked. Requires StormScope Pro. Double tap to unlock.")
    }

    private var lockPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PRO")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .kerning(1)
        }
        .foregroundStyle(Theme.cyan)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Theme.cyan.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Slim dashboard banner for the 3-day full-access trial: a countdown while
/// the trial runs, and a locked-state prompt once it ends. Hidden entirely
/// once Pro is owned.
struct TrialBannerView: View {
    let store: StoreViewModel
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: store.isTrialActive ? "sparkles" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.cyan.opacity(0.08))
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.cyan.opacity(0.2), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(subtitle). Double tap to open StormScope Pro.")
    }

    private var title: String {
        if store.isTrialActive {
            return "Full access — \(store.trialDaysRemaining) day\(store.trialDaysRemaining == 1 ? "" : "s") left"
        }
        return "Trial ended — StormScope Pro"
    }

    private var subtitle: String {
        if store.isTrialActive {
            return "Everything is unlocked. Keep it forever with a one-time purchase."
        }
        return "Core storm monitoring stays free. Unlock AI, radar & exports once."
    }
}

#Preview {
    VStack(spacing: 16) {
        TrialBannerView(store: StoreViewModel(), onOpen: {})
        PremiumTeaserCard(
            icon: "apple.intelligence",
            title: "Live Feedback",
            message: "On-device AI turns your pressure trend into plain-language storm guidance.",
            onUnlock: {}
        )
    }
    .padding(16)
    .background(Theme.ink)
}
