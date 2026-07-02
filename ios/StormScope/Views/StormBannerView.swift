import SwiftUI

/// Prominent storm-risk status banner with a subtle pulse at high severity.
struct StormBannerView: View {
    let level: StormLevel
    @State private var isPulsing = false

    private var isAlerting: Bool {
        level >= .stormLikely
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(level.tint.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .scaleEffect(isPulsing && isAlerting ? 1.18 : 1.0)
                Image(systemName: level.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(level.tint)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(level.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(level.detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [level.tint.opacity(0.16), Theme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(level.tint.opacity(isAlerting ? 0.5 : 0.25), lineWidth: 1)
        )
        .shadow(color: isAlerting ? level.tint.opacity(0.25) : .clear, radius: 14, y: 4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: level)
        .sensoryFeedback(.warning, trigger: isAlerting)
    }
}
