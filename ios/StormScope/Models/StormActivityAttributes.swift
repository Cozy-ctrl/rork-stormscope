import ActivityKit
import Foundation

/// Shared ActivityKit payload between the app and the widget extension.
/// NOTE: A copy of this file lives in the StormScopeWidget target — keep the
/// two definitions identical or Live Activity decoding will fail.
nonisolated struct StormActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// Latest calibrated pressure, in hPa.
        var pressureHPa: Double
        /// Least-squares 1-hour trend, in hPa/hour.
        var ratePerHour: Double?
        /// StormLevel raw value (0–5).
        var levelRaw: Int
        /// Number of active NWS alerts.
        var alertCount: Int
        /// Whether an NWS Tornado Warning is active.
        var hasTornadoWarning: Bool
        /// Recent pressure samples for the mini sparkline (oldest → newest).
        var sparkline: [Double]
        /// True when the user prefers inHg display.
        var usesImperial: Bool
        var updatedAt: Date
    }

    var startedAt: Date
}
