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
    /// Count of active NWS alerts at snapshot time (nil on old snapshots).
    let alertCount: Int?
    let updatedAt: Date
}

/// Reads/writes the shared snapshot in the App Group so the widget can render
/// without launching the app.
nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.xyz.stormscope"
    private static let snapshotKey = "stormscope.widget.snapshot"
    private static let tornadoModeKey = "stormscope.tornadoMode.shared"
    private static let legacyTornadoModeKey = "stormscope.tornadoMode"
    private static let refreshRequestKey = "stormscope.widget.refreshRequest"

    /// Tornado Mode flag shared with the widget through the App Group.
    /// Migrates the legacy app-local preference on first read.
    static var tornadoModeEnabled: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return UserDefaults.standard.bool(forKey: legacyTornadoModeKey)
        }
        if defaults.object(forKey: tornadoModeKey) == nil {
            let migrated = UserDefaults.standard.bool(forKey: legacyTornadoModeKey)
            defaults.set(migrated, forKey: tornadoModeKey)
            return migrated
        }
        return defaults.bool(forKey: tornadoModeKey)
    }

    static func setTornadoMode(_ enabled: Bool) {
        UserDefaults(suiteName: appGroupID)?.set(enabled, forKey: tornadoModeKey)
    }

    /// Returns true once if the widget requested a data refresh, then clears
    /// the flag so the request is handled exactly once.
    static func consumeRefreshRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              defaults.object(forKey: refreshRequestKey) != nil else { return false }
        defaults.removeObject(forKey: refreshRequestKey)
        return true
    }

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
