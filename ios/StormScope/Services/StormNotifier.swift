import Foundation
import UserNotifications

/// Sends time-sensitive local notifications when the barometer trend crosses
/// severe thresholds or an official NWS Tornado Warning becomes active.
/// De-duplicates so each escalation or warning notifies only once.
@Observable
final class StormNotifier {
    private static let notifiedAlertsKey = "stormscope.notifier.alertIDs"
    private static let lastLevelKey = "stormscope.notifier.lastLevel"

    private(set) var isAuthorized = false
    private(set) var isDenied = false

    private var notifiedAlertIDs: Set<String>

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.notifiedAlertsKey) ?? []
        notifiedAlertIDs = Set(saved)
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        isDenied = settings.authorizationStatus == .denied
    }

    /// Requests notification permission; returns whether it was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            isDenied = !granted
            return granted
        } catch {
            print("[Notifier] Authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Evaluates the current situation and fires any due notifications.
    func evaluate(
        assessment: StormAssessment,
        alerts: [NWSAlertFeature],
        stormNotificationsEnabled: Bool,
        tornadoAlertsEnabled: Bool
    ) async {
        guard isAuthorized else { return }

        if stormNotificationsEnabled {
            await evaluateStormLevel(assessment)
        }
        if tornadoAlertsEnabled {
            await evaluateTornadoWarnings(alerts)
        }
    }

    // MARK: - Storm level escalation

    private func evaluateStormLevel(_ assessment: StormAssessment) async {
        let lastNotified = UserDefaults.standard.integer(forKey: Self.lastLevelKey)
        let level = assessment.level

        // Reset the latch only once conditions genuinely calm (steady or
        // better). Holding the latch through .falling adds hysteresis so a
        // rate oscillating across the falling/storm boundary (-1.5 hPa/hour)
        // can't re-notify on every crossing.
        if level < .stormLikely {
            if level <= .steady && lastNotified != 0 {
                UserDefaults.standard.set(0, forKey: Self.lastLevelKey)
            }
            return
        }

        guard level.rawValue > lastNotified else { return }
        UserDefaults.standard.set(level.rawValue, forKey: Self.lastLevelKey)

        let rateText = assessment.ratePerHour.map { String(format: " (%.1f hPa/hour)", $0) } ?? ""
        let body: String
        if level == .frontImminent {
            body = "Severe pressure drop underway\(rateText). A storm front is arriving in your area."
        } else {
            body = "Rapid pressure drop detected\(rateText). A storm front may be approaching."
        }
        await send(
            identifier: "storm-level-\(level.rawValue)-\(Int(Date().timeIntervalSince1970))",
            title: level == .frontImminent ? "Front Imminent" : "Storm Watch",
            body: body,
            isCritical: level == .frontImminent
        )
    }

    // MARK: - Tornado warnings

    private func evaluateTornadoWarnings(_ alerts: [NWSAlertFeature]) async {
        let warnings = alerts.filter { $0.isTornadoWarning }
        for warning in warnings where !notifiedAlertIDs.contains(warning.id) {
            notifiedAlertIDs.insert(warning.id)
            persistNotifiedIDs(activeAlerts: alerts)
            await send(
                identifier: "tornado-\(warning.id.hashValue)",
                title: "Tornado Warning — Take Shelter",
                body: warning.properties.headline ?? "The National Weather Service issued a Tornado Warning for your location.",
                isCritical: true
            )
        }
        if warnings.isEmpty {
            persistNotifiedIDs(activeAlerts: alerts)
        }
    }

    /// Keeps only IDs still active so the persisted set can't grow forever.
    private func persistNotifiedIDs(activeAlerts: [NWSAlertFeature]) {
        let activeIDs = Set(activeAlerts.map { $0.id })
        notifiedAlertIDs.formIntersection(activeIDs)
        UserDefaults.standard.set(Array(notifiedAlertIDs), forKey: Self.notifiedAlertsKey)
    }

    // MARK: - Delivery

    private func send(identifier: String, title: String, body: String, isCritical: Bool) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isCritical ? .defaultCritical : .default
        content.interruptionLevel = isCritical ? .timeSensitive : .active

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("[Notifier] Failed to deliver notification: \(error.localizedDescription)")
        }
    }
}
