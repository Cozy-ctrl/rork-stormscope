import Foundation
import BackgroundTasks
import UserNotifications

/// Manages BGTaskScheduler for background barometer monitoring.
///
/// When the app enters background, a BGAppRefreshTask is scheduled to fire
/// approximately every 15 minutes. The task loads stored pressure history,
/// runs storm assessment, fetches NWS alerts, delivers time-sensitive or
/// critical notifications when thresholds are crossed, and refreshes the
/// widget snapshot — all while the app is closed.
///
/// Deduplication keys are shared with StormNotifier so foreground and
/// background notification paths don't double-fire.
nonisolated final class BackgroundBarometerService {
    static let taskIdentifier = "xyz.stormscope.barometer"
    static let shared = BackgroundBarometerService()

    private let store = PressureStore()

    // MARK: - Public API

    /// Call once during `application(_:didFinishLaunchingWithOptions:)`.
    /// No-op on devices without a barometer since pressure-based background
    /// monitoring depends on the sensor.
    func register() {
        guard DeviceCapability.hasBarometer else { return }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundRefresh(task: refreshTask)
        }
    }

    /// Schedule the next background refresh. No-op when background
    /// monitoring is disabled in settings or the device has no barometer.
    func schedule() {
        guard DeviceCapability.hasBarometer else { return }
        guard UserDefaults.standard.bool(forKey: "stormscope.settings.backgroundMonitoring") else { return }

        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BGService] Schedule failed: \(error.localizedDescription)")
        }
    }

    /// Cancel all pending background barometer tasks.
    func cancelAll() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
    }

    // MARK: - Task handler

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // Immediately schedule the next refresh
        schedule()

        task.expirationHandler = { [task] in
            task.setTaskCompleted(success: false)
        }

        let storeCapture = store

        Task.detached {
            let readings = storeCapture.load()
            guard !readings.isEmpty else {
                task.setTaskCompleted(success: true)
                return
            }

            let assessment = StormAssessment.assess(readings: readings)
            let alerts = await self.fetchBackgroundAlerts()

            await self.sendBackgroundNotifications(assessment: assessment, alerts: alerts)
            self.saveBackgroundSnapshot(readings: readings, assessment: assessment)

            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Alert fetching

    private func fetchBackgroundAlerts() async -> [NWSAlertFeature] {
        let lat = UserDefaults.standard.double(forKey: "stormscope.location.lat")
        let lon = UserDefaults.standard.double(forKey: "stormscope.location.lon")
        guard lat != 0 || lon != 0 else { return [] }

        let service = AlertsService()
        do {
            return try await service.fetchActiveAlerts(latitude: lat, longitude: lon)
        } catch {
            print("[BGService] Alert fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Notification delivery

    private func sendBackgroundNotifications(
        assessment: StormAssessment,
        alerts: [NWSAlertFeature]
    ) async {
        let stormEnabled = UserDefaults.standard.bool(forKey: "stormscope.settings.stormNotifications")
        let tornadoEnabled = UserDefaults.standard.bool(forKey: "stormscope.settings.tornadoAlerts")

        let center = UNUserNotificationCenter.current()
        let notifSettings = await center.notificationSettings()
        guard notifSettings.authorizationStatus == .authorized else { return }

        if stormEnabled {
            await sendStormNotification(center: center, assessment: assessment)
        }

        if tornadoEnabled {
            await sendTornadoNotifications(center: center, alerts: alerts)
        }
    }

    /// Escalates on storm level, sharing dedup keys with the foreground
    /// StormNotifier so a notification only fires once per escalation.
    private func sendStormNotification(
        center: UNUserNotificationCenter,
        assessment: StormAssessment
    ) async {
        let lastLevel = UserDefaults.standard.integer(forKey: "stormscope.notifier.lastLevel")
        let level = assessment.level

        // Reset the latch when conditions calm
        if level < .stormLikely {
            if lastLevel != 0 {
                UserDefaults.standard.set(0, forKey: "stormscope.notifier.lastLevel")
            }
            return
        }

        guard level.rawValue > lastLevel else { return }
        UserDefaults.standard.set(level.rawValue, forKey: "stormscope.notifier.lastLevel")

        let rateText = assessment.ratePerHour.map {
            String(format: " (%.1f hPa/hour)", $0)
        } ?? ""
        let content = UNMutableNotificationContent()

        if level == .frontImminent {
            content.title = "Front Imminent"
            content.body = "Severe pressure drop underway\(rateText). A storm front is arriving in your area."
            content.interruptionLevel = .timeSensitive
            content.sound = .defaultCritical
        } else {
            content.title = "Storm Watch"
            content.body = "Rapid pressure drop detected\(rateText). A storm front may be approaching."
            content.interruptionLevel = .timeSensitive
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "bg-storm-\(level.rawValue)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    /// Sends Critical Alerts for new tornado warnings, sharing dedup keys
    /// with the foreground StormNotifier.
    private func sendTornadoNotifications(
        center: UNUserNotificationCenter,
        alerts: [NWSAlertFeature]
    ) async {
        let warnedIDs = Set(UserDefaults.standard.stringArray(
            forKey: "stormscope.notifier.alertIDs"
        ) ?? [])

        for warning in alerts where warning.isTornadoWarning && !warnedIDs.contains(warning.id) {
            let content = UNMutableNotificationContent()
            content.title = "Tornado Warning — Take Shelter"
            content.body = warning.properties.headline
                ?? "The National Weather Service issued a Tornado Warning for your location."
            content.sound = .defaultCritical
            content.interruptionLevel = .timeSensitive

            let request = UNNotificationRequest(
                identifier: "bg-tornado-\(warning.id.hashValue)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }

        // Prune warned-IDs set to only active alerts so it never grows unbounded
        let activeIDs = Set(alerts.map(\.id))
        let cleaned = warnedIDs.intersection(activeIDs)
        UserDefaults.standard.set(Array(cleaned), forKey: "stormscope.notifier.alertIDs")
    }

    // MARK: - Widget snapshot

    private func saveBackgroundSnapshot(
        readings: [PressureReading],
        assessment: StormAssessment
    ) {
        guard let last = readings.last else { return }
        let units = UserDefaults.standard.string(forKey: "stormscope.settings.units")
        let usesImperial = units == UnitSystem.imperial.rawValue

        let sparkline = sparklineSamples(from: readings, maxCount: 36)
        let snapshot = WidgetSnapshot(
            pressureHPa: last.hPa,
            ratePerHour: assessment.ratePerHour,
            delta1h: assessment.delta1h,
            levelRaw: assessment.level.rawValue,
            levelTitle: assessment.level.title,
            sparkline: sparkline,
            usesImperial: usesImperial,
            updatedAt: Date()
        )
        WidgetSnapshotStore.save(snapshot)
    }

    private func sparklineSamples(from readings: [PressureReading], maxCount: Int) -> [Double] {
        let cutoff = Date().addingTimeInterval(-6 * 3600)
        let window = readings.filter { $0.timestamp >= cutoff }
        guard window.count > maxCount else { return window.map(\.hPa) }
        let stride = Double(window.count) / Double(maxCount)
        return (0..<maxCount).map {
            window[min(Int(Double($0) * stride), window.count - 1)].hPa
        }
    }
}
