import SwiftUI

/// The Storm Prediction Center's convective outlook for a specific point.
nonisolated struct SPCOutlook: Identifiable, Equatable {
    /// 1, 2, or 3 (Day 1–3 outlooks).
    let day: Int
    /// SPC categorical `dn` code (2 = TSTM … 8 = HIGH); nil when the point
    /// is outside every outlook polygon.
    let categoryCode: Int?
    /// Tornado probability percent (Day 1–2 only).
    let tornadoProbability: Int?
    /// Hail probability percent (Day 1–2 only).
    let hailProbability: Int?
    /// Wind probability percent (Day 1–2 only).
    let windProbability: Int?
    /// Combined severe probability percent (Day 3 only).
    let severeProbability: Int?

    var id: Int { day }

    var categoryTitle: String {
        switch categoryCode {
        case 2: return "Thunderstorms"
        case 3: return "Marginal Risk"
        case 4: return "Slight Risk"
        case 5: return "Enhanced Risk"
        case 6: return "Moderate Risk"
        case 7, 8: return "High Risk"
        default: return "No Severe Risk"
        }
    }

    var categoryShort: String {
        switch categoryCode {
        case 2: return "TSTM"
        case 3: return "MRGL"
        case 4: return "SLGT"
        case 5: return "ENH"
        case 6: return "MDT"
        case 7, 8: return "HIGH"
        default: return "NONE"
        }
    }

    var summary: String {
        switch categoryCode {
        case 2: return "General thunderstorms possible — severe weather not expected."
        case 3: return "Isolated severe storms possible."
        case 4: return "Scattered severe storms possible."
        case 5: return "Numerous severe storms possible."
        case 6: return "Widespread severe storms likely."
        case 7, 8: return "Severe weather outbreak expected — stay alert."
        default: return "SPC has no severe weather outlook for your area."
        }
    }
}

extension SPCOutlook {
    /// Tint for the category badge, mirroring SPC's public color scheme.
    var tint: Color {
        switch categoryCode {
        case 2: return Theme.green
        case 3: return Color(red: 0.40, green: 0.64, blue: 0.40)
        case 4: return Theme.amber
        case 5: return Theme.orange
        case 6: return Theme.red
        case 7, 8: return Color(red: 1.0, green: 0.30, blue: 0.75)
        default: return Theme.textTertiary
        }
    }
}
