import SwiftUI

/// A shimmering placeholder card shown while section content loads, so
/// collapsible sections expand to a stable height instead of glitching as
/// network cards pop in.
struct SkeletonCard: View {
    var height: CGFloat = 170
    var tint: Color = Theme.cyan

    @State private var shimmerPhase: CGFloat = -1.2

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, tint.opacity(0.09), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerPhase * 360)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 110, height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 190, height: 8)
                }
                .padding(16)
                .allowsHitTesting(false)
            }
            .frame(height: height)
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.panelStroke, lineWidth: 1)
            )
            .onAppear { startShimmer() }
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 1.4)
            .repeatForever(autoreverses: false)
        ) {
            shimmerPhase = 1.2
        }
    }
}

#Preview {
    SkeletonCard()
        .padding()
        .background(Theme.ink)
}
