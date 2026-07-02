import SwiftUI

/// Live plain-language pressure feedback. On iOS 26 devices with Apple
/// Intelligence, the on-device Foundation Model generates the text; older
/// devices fall back to StormScope's rule-based summary.
struct AIInsightCardView: View {
    let contextSummary: String
    let refreshKey: String
    let fallbackText: String

    var body: some View {
        if #available(iOS 26.0, *) {
            AIInsightLiveView(
                contextSummary: contextSummary,
                refreshKey: refreshKey,
                fallbackText: fallbackText
            )
        } else {
            AIInsightShellView(
                title: "On-device analysis",
                message: fallbackText,
                footnote: "Requires iOS 26 with Apple Intelligence. This device is running an older OS, so rule-based analysis is shown instead.",
                isThinking: false,
                confidence: nil
            )
        }
    }
}

@available(iOS 26.0, *)
private struct AIInsightLiveView: View {
    let contextSummary: String
    let refreshKey: String
    let fallbackText: String

    @State private var intelligence = StormIntelligence()

    var body: some View {
        AIInsightShellView(
            title: title,
            message: message,
            footnote: intelligence.guidance != nil ? "Generated on-device by Apple Intelligence — nothing leaves your iPhone" : nil,
            isThinking: intelligence.isThinking,
            confidence: intelligence.guidance != nil ? intelligence.confidence : nil
        )
        .task(id: refreshKey) {
            await intelligence.refresh(context: contextSummary)
        }
    }

    private var title: String {
        if let headline = intelligence.headline { return headline }
        if intelligence.unavailableReason != nil {
            return "Apple Intelligence unavailable"
        }
        return intelligence.isThinking ? "Reading the pressure…" : "On-device analysis"
    }

    private var message: String {
        if let reason = intelligence.unavailableReason {
            return "\(reason)\n\n\(fallbackText)"
        }
        return intelligence.guidance ?? fallbackText
    }
}

/// Shared card chrome for the intelligence insight.
private struct AIInsightShellView: View {
    let title: String
    let message: String
    let footnote: String?
    let isThinking: Bool
    let confidence: InsightConfidence?

    private let sparkleGradient = LinearGradient(
        colors: [Theme.cyan, Color(red: 0.65, green: 0.55, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(sparkleGradient)
                    .symbolEffect(.pulse, isActive: isThinking)
                Text("Live Feedback")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if isThinking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.cyan)
                } else if let confidence {
                    HStack(spacing: 4) {
                        Image(systemName: confidence.systemImage)
                            .font(.system(size: 9, weight: .semibold))
                        Text(confidence.title)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(confidence.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(confidence.tint.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(sparkleGradient)
                .fixedSize(horizontal: false, vertical: true)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(confidence == .low ? 0.85 : 1)

            if let footnote {
                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(sparkleGradient, lineWidth: 1)
                .opacity(0.35)
        )
        .animation(.easeInOut(duration: 0.35), value: title)
    }
}
