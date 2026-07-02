import Foundation

/// Persisted user preferences. Defaults to the device locale's measurement
/// system on first launch.
@Observable
final class AppSettings {
    private static let unitsKey = "stormscope.settings.units"
    private static let pressureUnitKey = "stormscope.settings.pressureUnit"
    private static let mslpEnabledKey = "stormscope.settings.mslpEnabled"
    private static let stormNotificationsKey = "stormscope.settings.stormNotifications"
    private static let tornadoAlertsKey = "stormscope.settings.tornadoAlerts"
    private static let backgroundMonitoringKey = "stormscope.settings.backgroundMonitoring"
    private static let calibrationOffsetKey = "stormscope.settings.calibrationOffset"
    private static let calibrationStationKey = "stormscope.settings.calibrationStation"
    private static let calibrationDateKey = "stormscope.settings.calibrationDate"

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
        stormNotificationsEnabled = defaults.bool(forKey: Self.stormNotificationsKey)
        tornadoAlertsEnabled = defaults.bool(forKey: Self.tornadoAlertsKey)
        backgroundMonitoringEnabled = defaults.bool(forKey: Self.backgroundMonitoringKey)
        mslpEnabled = defaults.bool(forKey: Self.mslpEnabledKey)
        calibrationOffset = defaults.double(forKey: Self.calibrationOffsetKey)
        calibrationStationID = defaults.string(forKey: Self.calibrationStationKey)
        calibratedAt = defaults.object(forKey: Self.calibrationDateKey) as? Date
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
        stormNotificationsEnabled = false
        tornadoAlertsEnabled = false
        backgroundMonitoringEnabled = false
        clearCalibration()
        UserDefaults.standard.removeObject(forKey: Self.unitsKey)
        UserDefaults.standard.removeObject(forKey: Self.pressureUnitKey)
        UserDefaults.standard.removeObject(forKey: Self.mslpEnabledKey)
    }
}
