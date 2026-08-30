import AppIntents
import WidgetKit

/// Refresh button on the widget: flags the shared store so a running app
/// performs a full remote refresh within its next monitor tick, and forces
/// the widget timeline to re-render immediately.
nonisolated struct RefreshPressureIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Pressure"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.requestRefresh()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Tornado Mode chip on the widget. Flips the shared App Group flag that the
/// app reads on launch and every monitor tick, so both surfaces agree.
nonisolated struct ToggleTornadoModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Tornado Mode"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        WidgetSnapshotStore.setTornadoMode(!WidgetSnapshotStore.tornadoModeEnabled)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
