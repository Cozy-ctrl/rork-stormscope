import Foundation

/// Persisted user preferences. Defaults to the device locale's measurement
/// system on first launch.
@Observable
final class AppSettings {
    private static let unitsKey = "stormscope.settings.units"
    private static let pressureUnitKey = "stormscope.settings.pressureUnit"
    private static let mslpEnabledKey = "stormscope.settings.mslpEnabled"
    private static let radarLayerModeKey = "stormscope.settings.radarLayerMode"
    private static let stormNotificationsKey = "stormscope.settings.stormNotifications"
    private static let tornadoAlertsKey = "stormscope.settings.tornadoAlerts"
    private static let backgroundMonitoringKey = "stormscope.settings.backgroundMonitoring"
    private static let calibrationOffsetKey = "stormscope.settings.calibrationOffset"
    private static let calibrationStationKey = "stormscope.settings.calibrationStation"
    private static let calibrationDateKey = "stormscope.settings.calibrationDate"
    private static let lightningDetectionKey = "stormscope.settings.lightningDetection"
    private static let stationsMapExpandedKey = "stormscope.settings.stationsMapExpanded"
    private static let stationsListExpandedKey = "stormscope.settings.stationsListExpanded"
    private static let chartPressureUnitKey = "stormscope.settings.chartPressureUnit"

    /// Whether the station map card is currently expanded. Defaults to collapsed
    /// so the dashboard stays compact until the user opens it.
    var stationsMapExpanded: Bool {
        didSet { UserDefaults.standard.set(stationsMapExpanded, forKey: Self.stationsMapExpandedKey) }
    }

    /// Whether the station list card is expanded. Collapsed by default so the
    /// detailed station rows do not dominate the dashboard until requested.
    var stationsListExpanded: Bool {
        didSet { UserDefaults.standard.set(stationsListExpanded, forKey: Self.stationsListExpandedKey) }
    }

    var unitSystem: UnitSystem {
        didSet { UserDefaults.standard.set(unitSystem.rawValue, forKey: Self.unitsKey) }
    }

    /// Independent pressure unit preference. Defaults to the primary unit of the
    /// locale's measurement system (hPa for metric regions, inHg for U.S.).
    var pressureDisplayMode: PressureDisplayMode {
        didSet { UserDefaults.standard.set(pressureDisplayMode.rawValue, forKey: Self.pressureUnitKey) }
    }

    /// When enabled, the device barometer reading is reduced to Mean Sea Level
    /// Pressure (MSLP) using GPS altitude and the current surface temperature.
    /// This makes readings directly comparable to NWS station reports (which are
    /// also sea-level-corrected) regardless of the user's elevation.
    var mslpEnabled: Bool {
        didSet { UserDefaults.standard.set(mslpEnabled, forKey: Self.mslpEnabledKey) }
    }

    /// Which imagery layers the radar map draws (radar, satellite, or both).
    var radarLayerMode: RadarLayerMode {
        didSet { UserDefaults.standard.set(radarLayerMode.rawValue, forKey: Self.radarLayerModeKey) }
    }

    /// Notify when the pressure trend escalates to Storm Watch / Front Imminent.
    var stormNotificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(stormNotificationsEnabled, forKey: Self.stormNotificationsKey) }
    }

    /// Time-sensitive notification when an NWS Tornado Warning goes active.
    var tornadoAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(tornadoAlertsEnabled, forKey: Self.tornadoAlertsKey) }
    }

    /// Keep sampling the barometer while the app is in the background using
    /// significant-location-change wakeups.
    var backgroundMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(backgroundMonitoringEnabled, forKey: Self.backgroundMonitoringKey) }
    }

    /// Additive hPa offset aligning the device barometer to an NWS station.
    /// Zero means uncalibrated. Applied at display time only — trend analysis
    /// always uses raw sensor data (a constant offset cancels out).
    private(set) var calibrationOffset: Double {
        didSet { UserDefaults.standard.set(calibrationOffset, forKey: Self.calibrationOffsetKey) }
    }

    private(set) var calibrationStationID: String? {
        didSet { UserDefaults.standard.set(calibrationStationID, forKey: Self.calibrationStationKey) }
    }

    private(set) var calibratedAt: Date? {
        didSet {
            if let calibratedAt {
                UserDefaults.standard.set(calibratedAt, forKey: Self.calibrationDateKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.calibrationDateKey)
            }
        }
    }

    /// Which unit the pressure trend chart uses. Independent of the gauge
    /// display mode so meteorologists can keep the chart in hPa (the global
    /// standard) even when their spot readout is in inHg. Defaults to hPa.
    var chartPressureUnit: PressureDisplayMode {
        didSet { UserDefaults.standard.set(chartPressureUnit.rawValue, forKey: Self.chartPressureUnitKey) }
    }

    /// When enabled, the device magnetometer streams and detects EMP spikes
    /// consistent with nearby lightning strikes. Turn off to save battery or
    /// when the device is in a noisy magnetic environment (near speakers,
    /// chargers, or strong magnets).
    var lightningDetectionEnabled: Bool {
        didSet { UserDefaults.standard.set(lightningDetectionEnabled, forKey: Self.lightningDetectionKey) }
    }

    /// Tracks whether the user has acknowledged the safety disclaimer on first launch.
    var hasAcceptedDisclaimer: Bool {
        get { UserDefaults.standard.bool(forKey: "stormscope.settings.disclaimerAccepted") }
        set { UserDefaults.standard.set(newValue, forKey: "stormscope.settings.disclaimerAccepted") }
    }

    var isCalibrated: Bool {
        abs(calibrationOffset) > 0.001
    }

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: Self.unitsKey),
           let saved = UnitSystem(rawValue: raw) {
            unitSystem = saved
        } else {
            unitSystem = Locale.current.measurementSystem == .us ? .imperial : .metric
        }
        if let raw = defaults.string(forKey: Self.pressureUnitKey),
           let saved = PressureDisplayMode(rawValue: raw) {
            pressureDisplayMode = saved
        } else {
            pressureDisplayMode = Locale.current.measurementSystem == .us ? .inHg : .hPa
        }
        if let raw = defaults.string(forKey: Self.radarLayerModeKey),
           let saved = RadarLayerMode(rawValue: raw) {
            radarLayerMode = saved
        } else {
            radarLayerMode = .radar
        }
        stormNotificationsEnabled = defaults.bool(forKey: Self.stormNotificationsKey)
        tornadoAlertsEnabled = defaults.bool(forKey: Self.tornadoAlertsKey)
        backgroundMonitoringEnabled = defaults.bool(forKey: Self.backgroundMonitoringKey)
        mslpEnabled = defaults.bool(forKey: Self.mslpEnabledKey)
        calibrationOffset = defaults.double(forKey: Self.calibrationOffsetKey)
        calibrationStationID = defaults.string(forKey: Self.calibrationStationKey)
        calibratedAt = defaults.object(forKey: Self.calibrationDateKey) as? Date
        if let raw = defaults.string(forKey: Self.chartPressureUnitKey),
           let saved = PressureDisplayMode(rawValue: raw), saved == .hPa || saved == .inHg {
            chartPressureUnit = saved
        } else {
            chartPressureUnit = .hPa
        }
        lightningDetectionEnabled = defaults.object(forKey: Self.lightningDetectionKey) == nil
            ? true
            : defaults.bool(forKey: Self.lightningDetectionKey)
        stationsMapExpanded = defaults.bool(forKey: Self.stationsMapExpandedKey)
        stationsListExpanded = defaults.bool(forKey: Self.stationsListExpandedKey)
    }

    /// Records a calibration offset aligned to a specific NWS station.
    func setCalibration(offset: Double, stationID: String) {
        calibrationOffset = offset
        calibrationStationID = stationID
        calibratedAt = Date()
    }

    /// Removes the calibration and returns to raw sensor readings.
    func clearCalibration() {
        calibrationOffset = 0
        calibrationStationID = nil
        calibratedAt = nil
    }

    /// Restores defaults and removes all persisted preferences.
    func reset() {
        unitSystem = Locale.current.measurementSystem == .us ? .imperial : .metric
        pressureDisplayMode = Locale.current.measurementSystem == .us ? .inHg : .hPa
        mslpEnabled = false
        radarLayerMode = .radar
        stormNotificationsEnabled = false
        tornadoAlertsEnabled = false
        backgroundMonitoringEnabled = false
        lightningDetectionEnabled = true
        stationsMapExpanded = false
        stationsListExpanded = false
        chartPressureUnit = .hPa
        clearCalibration()
        UserDefaults.standard.removeObject(forKey: Self.unitsKey)
        UserDefaults.standard.removeObject(forKey: Self.pressureUnitKey)
        UserDefaults.standard.removeObject(forKey: Self.mslpEnabledKey)
        UserDefaults.standard.removeObject(forKey: Self.radarLayerModeKey)
    }
}
