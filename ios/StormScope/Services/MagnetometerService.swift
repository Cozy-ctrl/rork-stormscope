import Foundation
import CoreMotion

/// Streams magnetometer readings and detects electromagnetic spikes
/// consistent with nearby lightning strikes.
///
/// Detection strategy: maintain a rolling baseline of the total magnetic
/// field strength (µT). When a reading exceeds baseline + threshold, flag
/// it as a potential strike. Consecutive spikes within a short window are
/// merged to avoid counting re-strikes as separate events.
///
/// The magnetometer on iPhone samples at roughly 100 Hz — fast enough to
/// catch the ~1 ms EMP from a close lightning discharge. At 1 km distance
/// typical spikes are 1–10 µT above ambient; at 10 km barely detectable.
@Observable
final class MagnetometerService {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    /// Rolling baseline of the total field magnitude (µT).
    private var baseline: Double?
    private let baselineAlpha: Double = 0.02  // slow-moving EMA

    /// Most recent reading and its time.
    private(set) var latestTotalField: Double?
    private(set) var latestTimestamp: Date?

    /// Detected strike events since the stream started.
    private(set) var recentStrikes: [MagneticStrikeEvent] = []
    private let maxStrikeHistory = 50

    /// Estimated distance label for the most recent strike.
    private(set) var proximityLabel: StrikeProximity = .none

    /// Whether the magnetometer stream is active.
    private(set) var isRunning = false

    /// True when the magnetometer hardware is unavailable.
    private(set) var isUnavailable = false

    /// The threshold, in µT, above the rolling baseline that triggers a strike event.
    private let spikeThreshold: Double = 2.5

    /// Minimum time between distinct strikes (seconds). Spikes closer than
    /// this are treated as the same discharge.
    private let mergeWindow: TimeInterval = 0.15

    var strikeCount: Int { recentStrikes.count }

    /// Most recent strike, if any.
    var lastStrike: MagneticStrikeEvent? { recentStrikes.last }

    /// Approximate distance in km for the most recent strike (coarse estimate).
    var estimatedDistanceKm: Double? { recentStrikes.last?.estimatedDistanceKm }

    /// Time since the last strike, in seconds. Nil if no strikes detected.
    var secondsSinceLastStrike: TimeInterval? {
        guard let last = recentStrikes.last else { return nil }
        return Date().timeIntervalSince(last.timestamp)
    }

    // MARK: - Start / Stop

    func start() {
        guard DeviceCapability.hasMagnetometer, manager.isMagnetometerAvailable else {
            isUnavailable = true
            return
        }
        guard !isRunning else { return }
        isUnavailable = false

        // Reduce baseline window on restart.
        baseline = nil
        proximityLabel = .none

        manager.magnetometerUpdateInterval = 1.0 / 60.0  // 60 Hz
        queue.maxConcurrentOperationCount = 1

        manager.startMagnetometerUpdates(to: queue) { [weak self] data, error in
            guard let self, let data else { return }
            self.process(data)
        }
        isRunning = true
    }

    func stop() {
        manager.stopMagnetometerUpdates()
        isRunning = false
    }

    /// Purge all recorded strikes (e.g. when the user moves location).
    func clearStrikes() {
        recentStrikes.removeAll()
        baseline = nil
        proximityLabel = .none
    }

    // MARK: - Processing

    private func process(_ data: CMMagnetometerData) {
        let field = data.magneticField
        let total = sqrt(field.x * field.x + field.y * field.y + field.z * field.z)

        let now = Date()
        latestTotalField = total
        latestTimestamp = now

        // Warm up the baseline with the first few readings.
        guard let base = baseline else {
            baseline = total
            return
        }

        // Update the rolling baseline (exponential moving average).
        baseline = base + baselineAlpha * (total - base)

        guard let baseline = baseline else { return }

        let deviation = total - baseline

        // Only flag positive spikes (lightning EMP adds field strength momentarily).
        guard deviation > spikeThreshold else { return }

        // Merge with the previous strike if within the merge window.
        if let last = recentStrikes.last,
           now.timeIntervalSince(last.timestamp) < mergeWindow {
            // Update the last strike magnitude if this spike is larger.
            if deviation > last.peakDeviation {
                recentStrikes[recentStrikes.count - 1] = MagneticStrikeEvent(
                    timestamp: last.timestamp,
                    totalField: total,
                    baseline: baseline,
                    peakDeviation: deviation
                )
            }
            return
        }

        let strike = MagneticStrikeEvent(
            timestamp: now,
            totalField: total,
            baseline: baseline,
            peakDeviation: deviation
        )
        recentStrikes.append(strike)
        if recentStrikes.count > maxStrikeHistory {
            recentStrikes.removeFirst(recentStrikes.count - maxStrikeHistory)
        }

        // Update proximity estimate.
        proximityLabel = strike.proximity

        // Haptic feedback on the main thread (approximate).
        Task { @MainActor in
            self.proximityLabel = strike.proximity
        }
    }
}
