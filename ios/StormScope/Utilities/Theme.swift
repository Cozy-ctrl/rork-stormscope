import SwiftUI

/// Central color palette for StormScope's dark instrument aesthetic.
nonisolated enum Theme {
    static let inkDeep = Color(red: 0.016, green: 0.027, blue: 0.055)
    static let ink = Color(red: 0.043, green: 0.063, blue: 0.110)
    static let panel = Color(red: 0.078, green: 0.106, blue: 0.173)
    static let panelStroke = Color.white.opacity(0.08)

    static let amber = Color(red: 0.93, green: 0.72, blue: 0.35)
    static let cyan = Color(red: 0.31, green: 0.85, blue: 0.92)
    static let green = Color(red: 0.42, green: 0.83, blue: 0.55)
    static let orange = Color(red: 0.98, green: 0.58, blue: 0.28)
    static let red = Color(red: 1.0, green: 0.36, blue: 0.36)

    static let textPrimary = Color.white.opacity(0.93)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
}
