import Foundation

/// A single barometric pressure sample in hectopascals.
nonisolated struct PressureReading: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let hPa: Double

    init(timestamp: Date, hPa: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.hPa = hPa
    }
}
