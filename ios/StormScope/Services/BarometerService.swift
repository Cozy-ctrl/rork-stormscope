import Foundation
import CoreMotion

/// Streams barometric pressure from the device's built-in barometer.
///
/// The cloud simulator has no barometer, so when the sensor is unavailable a
/// clearly-labeled simulated feed is used instead (a realistic falling-pressure
/// scenario so the storm-detection pipeline can be demonstrated).
@Observable
final class BarometerService {
    private(set) var currentPressure: Double?
    private(set) var readings: [PressureReading] = []
    private(set) var isSimulated = false
    private(set) var isRunning = false

    private let altimeter = CMAltimeter()
    private let store = PressureStore()
    private var simulationTask: Task<Void, Never>?
    private var lastRecordedAt: Date?
    private var simulatedBase: Double = 1017.0
    private var simulatedTick: Int = 0

    func start() {
        guard !isRunning else { return }
        isRunning = true

        if CMAltimeter.isRelativeAltitudeAvailable() {
            isSimulated = false
            readings = store.load()
            lastRecordedAt = readings.last?.timestamp
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
                if let error {
                    print("[Barometer] Update error: \(error.localizedDescription)")
                    return
                }
                guard let data else { return }
                let hPa = data.pressure.doubleValue * 10.0
                Task { @MainActor in
                    self?.ingest(pressure: hPa, persist: true)
                }
            }
        } else {
            isSimulated = true
            seedSimulatedHistory()
            simulationTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    self?.tickSimulation()
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if isSimulated {
            simulationTask?.cancel()
            simulationTask = nil
        } else {
            altimeter.stopRelativeAltitudeUpdates()
        }
    }

    /// Permanently clears recorded history (in memory and on disk). The live
    /// feed keeps running and rebuilds the trend from scratch.
    func clearHistory() {
        readings = []
        lastRecordedAt = nil
        store.clear()
    }

    /// Records the latest pressure and appends a history sample at most once
    /// per minute, keeping a rolling 24-hour window.
    private func ingest(pressure: Double, persist: Bool) {
        currentPressure = pressure
        let now = Date()
        if let last = lastRecordedAt, now.timeIntervalSince(last) < 60 {
            return
        }
        lastRecordedAt = now
        readings.append(PressureReading(timestamp: now, hPa: pressure))

        let cutoff = now.addingTimeInterval(-24 * 3600)
        if let firstValid = readings.firstIndex(where: { $0.timestamp >= cutoff }), firstValid > 0 {
            readings.removeFirst(firstValid)
        }
        if persist {
            store.save(readings)
        }
    }

    /// Builds six hours of synthetic history: a gentle fall that steepens in
    /// the final two hours, mimicking an approaching low-pressure front.
    private func seedSimulatedHistory() {
        let now = Date()
        var seeded: [PressureReading] = []
        var pressure = 1024.0
        let stepMinutes = 5.0
        let totalSteps = Int(6 * 60 / stepMinutes)

        for step in 0...totalSteps {
            let minutesAgo = Double(totalSteps - step) * stepMinutes
            let timestamp = now.addingTimeInterval(-minutesAgo * 60)
            let hoursIn = Double(step) * stepMinutes / 60.0
            let ratePerHour = hoursIn < 4 ? -0.9 : -1.7
            pressure += ratePerHour * (stepMinutes / 60.0)
            let noise = Double.random(in: -0.08...0.08)
            seeded.append(PressureReading(timestamp: timestamp, hPa: pressure + noise))
        }

        readings = seeded
        simulatedBase = pressure
        currentPressure = pressure
        lastRecordedAt = seeded.last?.timestamp
    }

    private func tickSimulation() {
        simulatedTick += 1
        // Continue falling at ~1.6 hPa/hour with gentle micro-variation.
        simulatedBase -= 1.6 / 1800.0
        let wobble = sin(Double(simulatedTick) / 14.0) * 0.12
        let noise = Double.random(in: -0.04...0.04)
        ingest(pressure: simulatedBase + wobble + noise, persist: false)
    }
}
