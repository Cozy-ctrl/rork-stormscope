import Foundation
import CoreMotion

/// Streams magnetometer readings and detects electromagnetic spikes
/// consistent with nearby lightning strikes.
///
/// Detection strategy — five layers of false-positive suppression:
///
/// 1. **Elevated threshold (8 µT).** Phone movement alone can produce
///    10–50 µT swings; 2.5 µT was far too low.
/// 2. **Transient-spike verification.** Real lightning EMP spikes and
///    decays in under a second. If the field stays elevated for >1 s
///    it is device movement, not a strike.
/// 3. **Baseline stability gate.** When the user is handling the phone
///    the rolling variance is high. Detections are suppressed until the
///    device has been stationary for at least 2 seconds.
/// 4. **Minimum strike interval (3 s).** Real cloud-to-ground lightning
///    does not discharge at 20 Hz; rapid-fire detections are noise.
/// 5. **Rolling rate cap.** No more than 10 flagged events per 60 s
///    window — excess events are discarded silently.
///
/// Even with all five gates, on-device magnetometer lightning detection
/// is a *probabilistic* signal, not a calibrated instrument. The app
/// treats it as one input among many (pressure trend, CAPE, radar,
/// alerts) rather than a standalone truth.
@Observable
final class MagnetometerService {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    // MARK: - Thresholds

    /// Minimum deviation above the rolling baseline (µT) required to
    /// consider a reading as a candidate spike.
    private let spikeThreshold: Double = 8.0

    /// Seconds after a spike during which the field must return to
    /// within `recoveryTolerance` of baseline. If it does not, the
    /// candidate is discarded as device movement.
    private let transientWindow: TimeInterval = 1.0

    /// How close to the pre-spike baseline the field must return to
    /// confirm the spike was transient (µT).
    private let recoveryTolerance: Double = 4.0

    /// Minimum time between distinct strike events (seconds).
    private let minimumStrikeInterval: TimeInterval = 3.0

    /// Maximum number of strike events allowed in a rolling 60-second
    /// window. Excess candidates are silently dropped.
    private let maxStrikesPerMinute = 10

    /// Number of seconds the device must be stationary (low variance)
    /// before the detector re-arms after movement.
    private let stabilityRequiredSeconds: TimeInterval = 2.0

    // MARK: - Internal state

    /// Rolling baseline of the total field magnitude (µT).
    private var baseline: Double?
    private let baselineAlpha: Double = 0.02

    /// Pre-spike baseline snapshot taken when a candidate is first seen.
    private var preSpikeBaseline: Double?
    private var preSpikeTime: Date?

    /// Whether we are currently waiting for a candidate spike to resolve
    /// (checking if it is transient or sustained).
    private var isTrackingCandidate = false

    /// Timestamp of the last *confirmed* strike event.
    private var lastConfirmedStrike: Date?

    /// Timestamps of recent confirmed strikes for rate-limiting.
    private var recentStrikeTimestamps: [Date] = []

    /// Rolling variance tracker for the stability gate.
    private var varianceWindow: [Double] = []
    private let varianceWindowSize = 30
    private var becameStableAt: Date?

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

    /// True while the detector is suppressed due to device movement.
    private(set) var isSuppressed = false

    // MARK: - Public accessors

    var strikeCount: Int { recentStrikes.count }
    var lastStrike: MagneticStrikeEvent? { recentStrikes.last }
    var estimatedDistanceKm: Double? { recentStrikes.last?.estimatedDistanceKm }

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

        baseline = nil
        preSpikeBaseline = nil
        preSpikeTime = nil
        isTrackingCandidate = false
        isSuppressed = false
        lastConfirmedStrike = nil
        recentStrikeTimestamps.removeAll()
        varianceWindow.removeAll()
        becameStableAt = nil
        proximityLabel = .none

        manager.magnetometerUpdateInterval = 1.0 / 60.0
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

    func clearStrikes() {
        recentStrikes.removeAll()
        baseline = nil
        preSpikeBaseline = nil
        preSpikeTime = nil
        isTrackingCandidate = false
        lastConfirmedStrike = nil
        recentStrikeTimestamps.removeAll()
        varianceWindow.removeAll()
        becameStableAt = nil
        proximityLabel = .none
    }

    // MARK: - Processing

    private func process(_ data: CMMagnetometerData) {
        let field = data.magneticField
        let total = sqrt(field.x * field.x + field.y * field.y + field.z * field.z)

        let now = Date()
        latestTotalField = total
        latestTimestamp = now

        // ---- Stability gate ----
        updateStabilityGate(total: total, now: now)
        if isSuppressed { return }

        // ---- Baseline warm-up ----
        guard let base = baseline else {
            baseline = total
            return
        }

        // Update the rolling baseline.
        baseline = base + baselineAlpha * (total - base)
        guard let currentBaseline = baseline else { return }

        let deviation = total - currentBaseline

        // ---- Transient-spike verification ----
        if isTrackingCandidate {
            handleCandidateResolution(total: total, baseline: currentBaseline, deviation: deviation, now: now)
            return
        }

        // Only positive deviations above threshold are candidates.
        guard deviation > spikeThreshold else { return }

        // Begin tracking a candidate spike.
        isTrackingCandidate = true
        preSpikeBaseline = currentBaseline
        preSpikeTime = now
    }

    // MARK: - Candidate resolution

    /// Called on each sample while a candidate spike is being tracked.
    /// If the field returns near baseline within `transientWindow` the
    /// candidate is confirmed as a strike. If it stays elevated past the
    /// window it is discarded as device movement.
    private func handleCandidateResolution(
        total: Double,
        baseline: Double,
        deviation: Double,
        now: Date
    ) {
        guard let preBase = preSpikeBaseline, let preTime = preSpikeTime else {
            // Should never happen, but reset safely.
            isTrackingCandidate = false
            return
        }

        let elapsed = now.timeIntervalSince(preTime)

        // Has the field returned close to the pre-spike baseline?
        let recovered = abs(total - preBase) <= recoveryTolerance

        if recovered {
            // Transient spike confirmed — a real lightning-like EMP signature.
            confirmStrike(peakDeviation: deviation, baseline: baseline, now: now)
            isTrackingCandidate = false
            preSpikeBaseline = nil
            preSpikeTime = nil
            return
        }

        // If the transient window has expired without recovery, discard.
        if elapsed >= transientWindow {
            isTrackingCandidate = false
            preSpikeBaseline = nil
            preSpikeTime = nil
            // Suppress briefly after a false candidate to let the baseline
            // re-stabilise without triggering another false positive.
            becameStableAt = nil
            varianceWindow.removeAll()
        }
    }

    // MARK: - Strike confirmation

    private func confirmStrike(peakDeviation: Double, baseline: Double, now: Date) {
        // Rate limit: minimum interval between strikes.
        if let last = lastConfirmedStrike,
           now.timeIntervalSince(last) < minimumStrikeInterval {
            return
        }

        // Rate limit: rolling one-minute cap.
        recentStrikeTimestamps = recentStrikeTimestamps.filter {
            now.timeIntervalSince($0) <= 60
        }
        if recentStrikeTimestamps.count >= maxStrikesPerMinute {
            return
        }

        recentStrikeTimestamps.append(now)
        lastConfirmedStrike = now

        let strike = MagneticStrikeEvent(
            timestamp: now,
            totalField: latestTotalField ?? 0,
            baseline: baseline,
            peakDeviation: peakDeviation
        )
        recentStrikes.append(strike)
        if recentStrikes.count > maxStrikeHistory {
            recentStrikes.removeFirst(recentStrikes.count - maxStrikeHistory)
        }

        // Push proximity to the main actor.
        let label = strike.proximity
        Task { @MainActor in
            self.proximityLabel = label
        }
    }

    // MARK: - Stability gate

    /// Tracks a rolling window of recent total-field magnitudes. When the
    /// variance exceeds a threshold the detector is suppressed until the
    /// device has been still for at least `stabilityRequiredSeconds`.
    private func updateStabilityGate(total: Double, now: Date) {
        varianceWindow.append(total)
        if varianceWindow.count > varianceWindowSize {
            varianceWindow.removeFirst(varianceWindow.count - varianceWindowSize)
        }
        guard varianceWindow.count >= 8 else { return }

        let mean = varianceWindow.reduce(0, +) / Double(varianceWindow.count)
        let variance = varianceWindow.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(varianceWindow.count)

        // When variance > 15 µT² the device is being handled.
        let isMoving = variance > 15.0

        if isMoving {
            becameStableAt = nil
            if !isSuppressed {
                isSuppressed = true
                // Reset any in-flight candidate.
                isTrackingCandidate = false
                preSpikeBaseline = nil
                preSpikeTime = nil
            }
        } else if isSuppressed {
            // Device has stopped moving — start the stability timer.
            if becameStableAt == nil {
                becameStableAt = now
            } else if now.timeIntervalSince(becameStableAt!) >= stabilityRequiredSeconds {
                isSuppressed = false
                becameStableAt = nil
            }
        }
    }
}
