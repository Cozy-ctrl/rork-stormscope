import SwiftUI

/// How firmly the AI insight stands behind its 30–60 minute prediction.
nonisolated enum InsightConfidence: String {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: return "Low confidence"
        case .medium: return "Medium confidence"
        case .high: return "High confidence"
        }
    }

    var tint: Color {
        switch self {
        case .low: return Theme.textTertiary
        case .medium: return Theme.amber
        case .high: return Theme.green
        }
    }

    var systemImage: String {
        switch self {
        case .low: return "cellularbars"
        case .medium: return "chart.bar.fill"
        case .high: return "checkmark.seal.fill"
        }
    }
}
