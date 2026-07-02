import Foundation
import WidgetKit

/// Snapshot of the latest barometer state shared with the home screen widget
/// through the App Group container.
/// NOTE: A copy of this file lives in the StormScopeWidget target — keep the
/// two definitions identical.
nonisolated struct WidgetSnapshot: Codable {
    let pressureHPa: Double
    let ratePerHour: Double?
    let delta1h: Double?
    let levelRaw: Int
    let levelTitle: String
    /// Last ~6 hours of samples, downsampled (oldest → newest).
    let sparkline: [Double]
    let usesImperial: Bool
    let updatedAt: Date
}

/// Reads/writes the shared snapshot in the App Group so the widget can render
/// without launching the app.
nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.xyz.stormscope"
    private static let snapshotKey = "stormscope.widget.snapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("[WidgetSnapshot] Encode failed: \(error.localizedDescription)")
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
