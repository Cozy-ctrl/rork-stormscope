import Foundation

/// Coordinates the barometer stream, location fix, weather fetches, NWS
/// alerts, tornado signature analysis, and Apple Intelligence context for
/// the main dashboard.
@Observable
final class DashboardViewModel {
    let barometer = BarometerService()
    let magnetometer = MagnetometerService()
    let location = LocationService()
    let settings = AppSettings()
    let notifier = StormNotifier()
    let liveActivity = LiveActivityController()

    private let weatherService = WeatherService()
    private let alertsService = AlertsService()
    private let stationsService = StationsService()
    private let outlookService = OutlookService()
    private let radarStatusService = RadarStatusService()
    private var monitorTask: Task<Void, Never>?

    private(set) var weather: WeatherSnapshot?
    private(set) var weatherError: String?
    private(set) var isLoadingWeather = false

    private(set) var alerts: [NWSAlertFeature] = []
    private(set) var alertsError: String?
    private(set) var isLoadingAlerts = false

    private(set) var stations: [StationObservation] = []
    private(set) var stationsError: String?
    private(set) var isLoadingStations = false

    private(set) var outlooks: [SPCOutlook] = []
    private(set) var isLoadingOutlook = false

    /// Health of the nearest NEXRAD site; nil while unknown or on lookup failure.
    private(set) var radarStatus: RadarSiteStatus?

    var isTornadoModeEnabled: Bool = UserDefaults.standard.bool(forKey: "stormscope.tornadoMode") {
        didSet { UserDefaults.standard.set(isTornadoModeEnabled, forKey: "stormscope.tornadoMode") }
    }

    var assessment: StormAssessment {
        StormAssessment.assess(readings: barometer.readings)
    }

    /// MSLP-corrected pressure when enabled, otherwise station pressure.
    /// Calibration offset is always applied on top.
    /// Trend analysis always uses raw station pressure — MSLP scaling is
    /// multiplicative so relative changes are preserved, and calibration
    /// is a constant offset that cancels out.
    var displayPressure: Double? {
        guard let raw = barometer.currentPressure else { return nil }
        let base = settings.mslpEnabled ? correctedToMSLP(raw) : raw
        return base + settings.calibrationOffset
    }

    /// Calibrated history for the trend chart, with MSLP applied when enabled.
    var displayReadings: [PressureReading] {
        let useMSLP = settings.mslpEnabled
        let offset = settings.calibrationOffset
        return barometer.readings.map { reading in
            let base = useMSLP ? correctedToMSLP(reading.hPa) : reading.hPa
            return PressureReading(timestamp: reading.timestamp, hPa: base + offset)
        }
    }

    /// Converts a raw station-pressure value to Mean Sea Level Pressure
    /// using the device's GPS altitude and the latest surface temperature
    /// from the weather model. Falls back to standard 15 °C when weather
    /// data hasn't arrived yet.
    private func correctedToMSLP(_ stationHPa: Double) -> Double {
        guard let altitude = location.altitude else { return stationHPa }
        return PressureCalculator.mslp(
            stationPressureHPa: stationHPa,
            altitudeM: altitude,
            temperatureC: weather?.temperature
        )
    }

    /// The nearest station that reported a pressure value — the calibration anchor.
    var calibrationCandidate: StationObservation? {
        stations.first { $0.pressureHPa != nil }
    }

    var tornadoSignature: TornadoSignature {
        TornadoSignature.analyze(
            readings: barometer.readings,
            cape: weather?.cape,
            liftedIndex: weather?.liftedIndex
        )
    }

    var hasTornadoWarning: Bool {
        alerts.contains { $0.isTornadoWarning }
    }

    var hasTornadoWatch: Bool {
        alerts.contains { $0.isTornadoWatch }
    }

    /// Difference between the device barometer and the weather model's
    /// surface pressure. When MSLP is enabled both values are sea-level
    /// corrected, so the delta reflects true sensor-model disagreement
    /// rather than altitude difference.
    var sensorVsStationDelta: Double? {
        guard let device = displayPressure, let modelPressure = weather?.stationPressure else { return nil }
        let modelMSLP: Double
        if settings.mslpEnabled, let altitude = location.altitude {
            modelMSLP = PressureCalculator.mslp(
                stationPressureHPa: modelPressure,
                altitudeM: altitude,
                temperatureC: weather?.temperature
            )
        } else {
            modelMSLP = modelPressure
        }
        return device - modelMSLP
    }

    /// Compact live-sensor context fed to the on-device Foundation Model.
    var intelligenceContext: String {
        var parts: [String] = []
        if let pressure = displayPressure {
            parts.append(String(format: "Current pressure: %.1f hPa%@", pressure, settings.mslpEnabled ? " (MSLP)" : ""))
        }
        if let altitude = location.altitude {
            parts.append(String(format: "Device altitude: %.0f m", altitude))
        }
        if let rate = assessment.ratePerHour {
            parts.append(String(format: "1-hour trend: %+.2f hPa/hour", rate))
        }
        if let d3 = assessment.delta3h {
            parts.append(String(format: "3-hour change: %+.1f hPa", d3))
        }
        if let d6 = assessment.delta6h {
            parts.append(String(format: "6-hour change: %+.1f hPa", d6))
        }
        parts.append("Status: \(assessment.level.title)")
        if isTornadoModeEnabled, let drop = tornadoSignature.drop10m {
            parts.append(String(format: "10-minute change: %+.2f hPa (tornado signature mode)", drop))
        }
        if hasTornadoWarning {
            parts.append("An official NWS Tornado Warning is ACTIVE for this location.")
        } else if hasTornadoWatch {
            parts.append("An official NWS Tornado Watch is active for this region.")
        } else if let top = alerts.first {
            parts.append("Active NWS alert: \(top.properties.event)")
        }
        if let weather {
            var weatherLine = String(
                format: "Conditions: %@, %.0f°C, wind %.0f km/h, humidity %d%%",
                WeatherCode.description(weather.weatherCode),
                weather.temperature,
                weather.windSpeed,
                weather.humidity
            )
            if let dew = weather.dewPoint {
                weatherLine += String(format: ", dew point %.0f°C", dew)
            }
            if let cape = weather.cape {
                weatherLine += ", CAPE \(Int(cape)) J/kg"
            }
            if let liftedIndex = weather.liftedIndex {
                weatherLine += String(format: ", Lifted Index %.1f", liftedIndex)
            }
            if let gusts = weather.windGust {
                weatherLine += String(format: ", gusts %.0f km/h", gusts)
            }
            parts.append(weatherLine)
            if let rate = weather.precipitationNow, rate >= 0.1 {
                parts.append(String(format: "Precipitation falling now: %.1f mm/h", rate))
            }
            if let total = weather.precipitationLast24h, total >= 1 {
                parts.append(String(format: "24-hour precipitation total: %.1f mm", total))
            }
        }
        if let windStation = stations.first(where: { $0.windSpeedKmh != nil }),
           let observedWind = windStation.windSpeedKmh {
            var windLine = String(format: "Observed wind at station %@ (%.0f km away): %.0f km/h", windStation.id, windStation.distanceKm, observedWind)
            if let direction = windStation.windDirectionDeg {
                windLine += String(format: " from %.0f°", direction)
            }
            if let gust = windStation.windGustKmh {
                windLine += String(format: ", gusting %.0f km/h", gust)
            }
            parts.append(windLine)
        }
        if magnetometer.strikeCount > 0 {
            if let dist = magnetometer.estimatedDistanceKm {
                parts.append("Lightning: \(magnetometer.strikeCount) close-range strikes detected in the last hour, last ~\(String(format: "%.1f", dist)) km away")
            } else {
                parts.append("Lightning: \(magnetometer.strikeCount) close-range strikes detected in the last hour")
            }
        }
        if let day1 = outlooks.first(where: { $0.day == 1 }) {
            var outlookLine = "SPC Day 1 outlook: \(day1.categoryTitle)"
            if let tornado = day1.tornadoProbability {
                outlookLine += ", tornado probability \(tornado)%"
            }
            parts.append(outlookLine)
        }
        return parts.joined(separator: "\n")
    }

    /// Coarse identity for the AI insight so it regenerates only when the
    /// situation meaningfully changes (level, half-hPa rate bucket, tornado
    /// state, lightning proximity bucket) instead of on every sensor tick.
    var intelligenceKey: String {
        let rateBucket = assessment.ratePerHour.map { String(format: "%.1f", ($0 * 2).rounded() / 2) } ?? "none"
        let tornado = "\(tornadoSignature.status.rawValue)-\(hasTornadoWarning)-\(hasTornadoWatch)"
        let outlook = outlooks.first { $0.day == 1 }?.categoryCode ?? -1
        let lightning = magnetometer.proximityLabel.rawValue
        return "\(assessment.level.rawValue)|\(rateBucket)|\(tornado)|\(weather != nil)|\(outlook)|\(lightning)"
    }

    func start() {
        barometer.start()
        if settings.lightningDetectionEnabled {
            magnetometer.start()
        }
        location.request()
        location.setBackgroundMonitoring(settings.backgroundMonitoringEnabled)
        liveActivity.adoptExistingActivity()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.saveWidgetSnapshot()
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            self?.location.applyFallbackIfNeeded()
        }
        Task { [weak self] in
            await self?.notifier.refreshAuthorizationStatus()
        }
        startMonitorLoop()
    }

    /// Periodic watchdog: evaluates notification thresholds, pushes Live
    /// Activity updates, and refreshes the widget snapshot once a minute.
    private func startMonitorLoop() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.notifier.evaluate(
                    assessment: self.assessment,
                    alerts: self.alerts,
                    stormNotificationsEnabled: self.settings.stormNotificationsEnabled,
                    tornadoAlertsEnabled: self.settings.tornadoAlertsEnabled
                )
                self.pushLiveActivityUpdate()
                self.saveWidgetSnapshot()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// Refreshes weather, NWS alerts, stations, and the SPC outlook concurrently.
    func refreshRemote() async {
        async let weatherTask: Void = refreshWeather()
        async let alertsTask: Void = refreshAlerts()
        async let stationsTask: Void = refreshStations()
        async let outlookTask: Void = refreshOutlook()
        async let radarStatusTask: Void = refreshRadarStatus()
        _ = await (weatherTask, alertsTask, stationsTask, outlookTask, radarStatusTask)
        await notifier.evaluate(
            assessment: assessment,
            alerts: alerts,
            stormNotificationsEnabled: settings.stormNotificationsEnabled,
            tornadoAlertsEnabled: settings.tornadoAlertsEnabled
        )
        pushLiveActivityUpdate(force: hasTornadoWarning)
        saveWidgetSnapshot()
    }

    /// Permanently deletes recorded pressure history and resets preferences.
    func deleteAllData() {
        barometer.clearHistory()
        isTornadoModeEnabled = false
        settings.reset()
        location.setBackgroundMonitoring(false)
        liveActivity.end()
    }

    // MARK: - Calibration

    /// Aligns the device barometer to the nearest reporting NWS station.
    /// Returns true when an offset was recorded.
    @discardableResult
    func calibrateToNearestStation() -> Bool {
        guard let device = displayPressure,
              let station = calibrationCandidate,
              let stationPressure = station.pressureHPa else {
            return false
        }
        // NWS stations report sea-level-corrected pressure.
        // When MSLP is enabled on the device, both are on the same
        // reference plane and the offset should be minimal (sensor drift only).
        // When MSLP is off, the offset includes the altitude difference.
        settings.setCalibration(offset: stationPressure - device, stationID: station.id)
        return true
    }

    // MARK: - Background & Live Activity toggles

    func applyBackgroundMonitoringSetting() {
        location.setBackgroundMonitoring(settings.backgroundMonitoringEnabled)
    }

    /// Starts or stops the magnetometer stream based on the user's preference
    /// and device capability. Called whenever the toggle changes.
    func applyMagnetometerSetting() {
        if settings.lightningDetectionEnabled && DeviceCapability.hasMagnetometer {
            magnetometer.start()
        } else {
            magnetometer.stop()
            magnetometer.clearStrikes()
        }
    }

    func toggleLiveActivity() {
        if liveActivity.isRunning {
            liveActivity.end()
        } else if let state = liveActivityState() {
            liveActivity.start(with: state)
        }
    }

    private func pushLiveActivityUpdate(force: Bool = false) {
        guard liveActivity.isRunning, let state = liveActivityState() else { return }
        liveActivity.update(with: state, force: force)
    }

    private func liveActivityState() -> StormActivityAttributes.ContentState? {
        guard let pressure = displayPressure else { return nil }
        return StormActivityAttributes.ContentState(
            pressureHPa: pressure,
            ratePerHour: assessment.ratePerHour,
            levelRaw: assessment.level.rawValue,
            alertCount: alerts.count,
            hasTornadoWarning: hasTornadoWarning,
            sparkline: sparklineSamples(maxCount: 24),
            usesImperial: settings.unitSystem == .imperial,
            updatedAt: Date()
        )
    }

    // MARK: - Widget snapshot

    private func saveWidgetSnapshot() {
        guard let pressure = displayPressure else { return }
        WidgetSnapshotStore.save(
            WidgetSnapshot(
                pressureHPa: pressure,
                ratePerHour: assessment.ratePerHour,
                delta1h: assessment.delta1h,
                levelRaw: assessment.level.rawValue,
                levelTitle: assessment.level.title,
                sparkline: sparklineSamples(maxCount: 36),
                usesImperial: settings.unitSystem == .imperial,
                updatedAt: Date()
            )
        )
    }

    /// Downsampled calibrated pressure history (last ~6 hours) for sparklines.
    private func sparklineSamples(maxCount: Int) -> [Double] {
        let cutoff = Date().addingTimeInterval(-6 * 3600)
        let window = displayReadings.filter { $0.timestamp >= cutoff }
        guard window.count > maxCount else { return window.map { $0.hPa } }
        let stride = Double(window.count) / Double(maxCount)
        return (0..<maxCount).map { window[min(Int(Double($0) * stride), window.count - 1)].hPa }
    }

    func refreshWeather() async {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        isLoadingWeather = true
        weatherError = nil
        do {
            weather = try await weatherService.fetch(latitude: lat, longitude: lon)
        } catch {
            weatherError = "Couldn't load local weather. Pull to retry."
            print("[Weather] Fetch failed: \(error.localizedDescription)")
        }
        isLoadingWeather = false
    }

    func refreshAlerts() async {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        isLoadingAlerts = true
        alertsError = nil
        do {
            alerts = try await alertsService.fetchActiveAlerts(latitude: lat, longitude: lon)
        } catch AlertsServiceError.outsideCoverage {
            alerts = []
            alertsError = "NWS alerts cover U.S. locations only."
        } catch {
            alertsError = "Couldn't load NWS alerts. Pull to retry."
            print("[Alerts] Fetch failed: \(error.localizedDescription)")
        }
        isLoadingAlerts = false
    }

    func refreshOutlook() async {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        isLoadingOutlook = true
        outlooks = await outlookService.fetchOutlooks(latitude: lat, longitude: lon)
        isLoadingOutlook = false
    }

    func refreshRadarStatus() async {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        radarStatus = await radarStatusService.fetchStatus(latitude: lat, longitude: lon)
    }

    func refreshStations() async {
        guard let lat = location.latitude, let lon = location.longitude else { return }
        isLoadingStations = true
        stationsError = nil
        do {
            stations = try await stationsService.fetchNearbyObservations(latitude: lat, longitude: lon)
            if stations.isEmpty {
                stationsError = "No recent observations from nearby stations."
            }
        } catch StationsServiceError.outsideCoverage {
            stations = []
            stationsError = "NWS stations cover U.S. locations only."
        } catch {
            stationsError = "Couldn't reach NWS stations. Pull to retry."
            print("[Stations] Fetch failed: \(error.localizedDescription)")
        }
        isLoadingStations = false
    }
}
