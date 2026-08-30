import AppIntents
import Foundation

/// Siri/Shortcuts intent that reports the latest barometric snapshot without
/// opening the app. Reads the shared App Group store so it works even when
/// the app process is cold; the answer mirrors the dashboard's gauge.
nonisolated struct CheckStormStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Storm Status"
    static var description = IntentDescription(
        "Reports the current barometric pressure, trend, storm level, and active NWS alerts from StormScope.",
        categoryName: "Weather"
    )
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = WidgetSnapshotStore.load() else {
            return .result(dialog: "StormScope doesn't have any pressure data yet. Open the app once to start tracking.")
        }

        var text = "Pressure \(pressureText(snapshot)) — \(snapshot.levelTitle)."
        if let rate = snapshot.ratePerHour {
            let direction = rate < -0.3 ? "falling" : rate > 0.3 ? "rising" : "steady"
            text += " Trend \(direction) at \(String(format: "%.1f", abs(rate))) hPa per hour."
        }
        if let alertCount = snapshot.alertCount, alertCount > 0 {
            text += " \(alertCount) active weather alert\(alertCount == 1 ? "" : "s")."
        }
        let ageMinutes = max(0, Int(Date().timeIntervalSince(snapshot.updatedAt) / 60))
        if ageMinutes >= 1 {
            text += " Updated \(ageMinutes < 60 ? "\(ageMinutes) minutes" : "\(ageMinutes / 60) hours") ago."
        }
        return .result(dialog: IntentDialog(stringLiteral: text))
    }

    private func pressureText(_ snapshot: WidgetSnapshot) -> String {
        let unit = snapshot.usesImperial ? " inHg" : " hPa"
        let value = snapshot.usesImperial ? String(format: "%.2f", snapshot.pressureHPa * 0.029529983) : String(format: "%.1f", snapshot.pressureHPa)
        return value + unit
    }
}

/// Exposes the status check to Siri phrases and the Shortcuts/Spotlight index.
nonisolated struct StormShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckStormStatusIntent(),
            phrases: [
                "Check storm status in \(.applicationName)",
                "What's the storm status in \(.applicationName)"
            ],
            shortTitle: "Storm Status",
            systemImageName: "cloud.bolt.fill"
        )
    }
}
