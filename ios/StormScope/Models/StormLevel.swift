import SwiftUI

/// Severity classification derived from the barometric pressure tendency.
/// Ordered by increasing storm risk so levels can be compared.
nonisolated enum StormLevel: Int, Comparable, CaseIterable {
    case collecting = 0
    case rising = 1
    case steady = 2
    case falling = 3
    case stormLikely = 4
    case frontImminent = 5

    static func < (lhs: StormLevel, rhs: StormLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .collecting: return "Calibrating"
        case .rising: return "Clearing"
        case .steady: return "Stable"
        case .falling: return "Change Coming"
        case .stormLikely: return "Storm Watch"
        case .frontImminent: return "Front Imminent"
        }
    }

    var detail: String {
        switch self {
        case .collecting: return "Gathering pressure samples from the barometer. Trend analysis begins after ~15 minutes of data."
        case .rising: return "Pressure is rising — conditions should improve over the next hours."
        case .steady: return "Pressure is holding steady. No fronts detected nearby."
        case .falling: return "Pressure is falling. Weather may deteriorate in the coming hours."
        case .stormLikely: return "Rapid pressure drop detected — a storm may develop in your area over the coming hours."
        case .frontImminent: return "Severe pressure drop underway — a strong front is likely arriving. Check official alerts and secure loose items."
        }
    }

    var systemImage: String {
        switch self {
        case .collecting: return "gauge.with.dots.needle.50percent"
        case .rising: return "sun.max.fill"
        case .steady: return "cloud.sun.fill"
        case .falling: return "cloud.fill"
        case .stormLikely: return "cloud.bolt.fill"
        case .frontImminent: return "cloud.bolt.rain.fill"
        }
    }

    var tint: Color {
        switch self {
        case .collecting: return Theme.textSecondary
        case .rising: return Theme.cyan
        case .steady: return Theme.green
        case .falling: return Theme.amber
        case .stormLikely: return Theme.orange
        case .frontImminent: return Theme.red
        }
    }
}
