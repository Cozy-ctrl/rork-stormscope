import Foundation
import CoreMotion
import ActivityKit

/// Centralized hardware and OS capability checks so every view and service
/// can query device support without importing platform frameworks directly.
///
/// All properties are static and evaluated once at first access (lazily),
/// since hardware capabilities don't change during an app session.
nonisolated enum DeviceCapability {

    /// Whether this device has a working barometer (CMAltimeter).
    ///
    /// False on: iPad, iPod touch, older iPhones, and all simulators.
    /// When false the app falls back to a simulated pressure feed for
    /// demonstration, and barometer-dependent features (background
    /// monitoring, sensor calibration) are disabled.
    static let hasBarometer: Bool = CMAltimeter.isRelativeAltitudeAvailable()

    /// Whether Live Activities can be started on this device.
    ///
    /// Live Activities require iOS 16.1+ and must not be disabled in
    /// Settings. Even without a barometer the Live Activity can still
    /// show NWS alert status and weather data.
    static let hasLiveActivities: Bool = {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }()

    /// Whether this device has a magnetometer (compass).
    ///
    /// Present on every iPhone since the 3GS. The magnetometer detects
    /// electromagnetic pulses from nearby lightning strikes, so StormScope
    /// uses it for strike proximity estimation.
    static let hasMagnetometer: Bool = CMMotionManager().isMagnetometerAvailable

    /// Coarse check: is the OS version high enough that Apple Intelligence
    /// APIs (FoundationModels) exist?
    ///
    /// A `true` value does NOT mean Apple Intelligence is enabled —
    /// use ``appleIntelligenceAvailability`` for the runtime status.
    static let supportsAppleIntelligenceAPI: Bool = {
        if #available(iOS 26.0, *) { return true }
        return false
    }()
}
