import ActivityKit
import SwiftUI

// Widget-target copies of shared types.
// NOTE: These must stay byte-identical to the app's definitions in
// StormScope/Models/StormActivityAttributes.swift and
// StormScope/Services/WidgetSnapshotStore.swift.

nonisolated struct StormActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var pressureHPa: Double
        var ratePerHour: Double?
        var levelRaw: Int
        var alertCount: Int
        var hasTornadoWarning: Bool
        var sparkline: [Double]
        var usesImperial: Bool
        var updatedAt: Date
    }

    var startedAt: Date
}

nonisolated struct WidgetSnapshot: Codable {
    let pressureHPa: Double
    let ratePerHour: Double?
    let delta1h: Double?
    let levelRaw: Int
    let levelTitle: String
    let sparkline: [Double]
    let usesImperial: Bool
    let alertCount: Int?
    let updatedAt: Date
}

nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.xyz.stormscope"
    private static let snapshotKey = "stormscope.widget.snapshot"
    private static let tornadoModeKey = "stormscope.tornadoMode.shared"
    private static let refreshRequestKey = "stormscope.widget.refreshRequest"

    /// Tornado Mode flag shared with the app through the App Group.
    static var tornadoModeEnabled: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: tornadoModeKey) ?? false
    }

    static func setTornadoMode(_ enabled: Bool) {
        UserDefaults(suiteName: appGroupID)?.set(enabled, forKey: tornadoModeKey)
    }

    /// Flags the running app to perform a full remote refresh on its next
    /// monitor tick.
    static func requestRefresh() {
        UserDefaults(suiteName: appGroupID)?.set(Date().timeIntervalSince1970, forKey: refreshRequestKey)
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("[WidgetSnapshot] UserDefaults suite \(appGroupID) not available. Check App Group capability.")
            return nil
        }
        guard let data = defaults.data(forKey: snapshotKey) else {
            print("[WidgetSnapshot] No snapshot data found for key '\(snapshotKey)'")
            return nil
        }
        do {
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        } catch {
            print("[WidgetSnapshot] Decode failed: \(error.localizedDescription)")
            return nil
        }
    }
}

/// Compact styling helpers shared by the widget and Live Activity views.
nonisolated enum StormStyle {
    static func title(for levelRaw: Int) -> String {
        switch levelRaw {
        case 1: return "Clearing"
        case 2: return "Stable"
        case 3: return "Change Coming"
        case 4: return "Storm Watch"
        case 5: return "Front Imminent"
        default: return "Calibrating"
        }
    }

    static func tint(for levelRaw: Int) -> Color {
        switch levelRaw {
        case 1: return Color(red: 0.31, green: 0.85, blue: 0.92)
        case 2: return Color(red: 0.42, green: 0.83, blue: 0.55)
        case 3: return Color(red: 0.93, green: 0.72, blue: 0.35)
        case 4: return Color(red: 0.98, green: 0.58, blue: 0.28)
        case 5: return Color(red: 1.0, green: 0.36, blue: 0.36)
        default: return Color.white.opacity(0.55)
        }
    }

    static func icon(for levelRaw: Int) -> String {
        switch levelRaw {
        case 1: return "sun.max.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 4: return "cloud.bolt.fill"
        case 5: return "cloud.bolt.rain.fill"
        default: return "gauge.with.dots.needle.50percent"
        }
    }

    static func pressureText(_ hPa: Double, imperial: Bool) -> String {
        imperial ? String(format: "%.2f", hPa * 0.029529983) : String(format: "%.1f", hPa)
    }

    static func pressureUnit(imperial: Bool) -> String {
        imperial ? "inHg" : "hPa"
    }

    static func rateText(_ hPaPerHour: Double, imperial: Bool) -> String {
        imperial
            ? String(format: "%+.3f inHg/h", hPaPerHour * 0.029529983)
            : String(format: "%+.1f hPa/h", hPaPerHour)
    }
}

/// Minimal line sparkline for widgets and the Live Activity.
nonisolated struct SparklineShape: Shape {
    let samples: [Double]

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count >= 2,
              let minValue = samples.min(),
              let maxValue = samples.max() else { return path }
        let range = max(maxValue - minValue, 0.2)
        let stepX = rect.width / CGFloat(samples.count - 1)

        for (index, value) in samples.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let y = rect.maxY - CGFloat((value - minValue) / range) * rect.height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
