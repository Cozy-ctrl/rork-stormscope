import Foundation

/// Persists the rolling pressure history so trends survive app relaunches.
nonisolated final class PressureStore {
    private let key = "stormscope.pressure.history.v1"

    func load() -> [PressureReading] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            let readings = try JSONDecoder().decode([PressureReading].self, from: data)
            let cutoff = Date().addingTimeInterval(-24 * 3600)
            return readings.filter { $0.timestamp >= cutoff }
        } catch {
            print("[PressureStore] Failed to decode history: \(error.localizedDescription)")
            return []
        }
    }

    /// Permanently removes all persisted pressure history.
    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func save(_ readings: [PressureReading]) {
        do {
            let data = try JSONEncoder().encode(readings)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("[PressureStore] Failed to encode history: \(error.localizedDescription)")
        }
    }
}
