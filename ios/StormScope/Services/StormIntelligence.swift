import Foundation
import FoundationModels

/// Structured feedback generated on-device by Apple Intelligence.
@available(iOS 26.0, *)
@Generable
struct PressureInsight {
    @Guide(description: "Plain-language headline about the current pressure trend, under 8 words")
    var headline: String

    @Guide(description: "Two short sentences: whether the trend is likely to cross a storm threshold in the next 30-60 minutes based ONLY on the provided data, and one calm, practical tip")
    var guidance: String

    @Guide(description: "Confidence in the prediction, exactly one of: low, medium, high. Use low when data is sparse or the trend is flat, high only when a strong sustained trend is corroborated by official alerts or outlook data")
    var confidence: String
}

/// Runs the on-device Foundation Model over live barometer context and
/// produces short plain-language feedback. Fully offline, no credits.
@available(iOS 26.0, *)
@Observable
final class StormIntelligence {
    private(set) var headline: String?
    private(set) var guidance: String?
    private(set) var confidence: InsightConfidence?
    private(set) var isThinking = false
    private(set) var unavailableReason: String?

    func refresh(context: String) async {
        switch SystemLanguageModel.default.availability {
        case .available:
            unavailableReason = nil
        case .unavailable(.appleIntelligenceNotEnabled):
            unavailableReason = "Turn on Apple Intelligence in Settings to get live pressure feedback."
            return
        case .unavailable(.modelNotReady):
            unavailableReason = "The on-device model is still downloading — live feedback will appear soon."
            return
        case .unavailable(.deviceNotEligible):
            unavailableReason = "This device can't run Apple Intelligence, so rule-based analysis is shown instead."
            return
        default:
            unavailableReason = "Apple Intelligence is unavailable right now."
            return
        }

        isThinking = true
        defer { isThinking = false }

        // Fresh single-shot session each refresh keeps the context window small.
        let session = LanguageModelSession {
            "You are StormScope's on-device severe-weather assistant."
            "You receive live barometric readings from the iPhone's pressure sensor, the SPC severe weather outlook, and official NWS alert status."
            "Predict whether the pressure trend will cross a storm threshold within the next 30-60 minutes, anchored strictly to the provided numbers."
            "NEVER mention tornadoes unless the context explicitly states an active NWS Tornado Watch or Warning, or an SPC tornado probability of 5% or higher."
            "Stay calm, proportionate, and factual. DO NOT invent data that was not provided. DO NOT exaggerate danger. A falling trend alone means rain or wind is possible, not a disaster."
            "Give one calm, practical tip appropriate to the actual risk level."
        }

        do {
            let response = try await session.respond(
                to: "Live sensor data:\n\(context)\n\nGive feedback on this pressure trend.",
                generating: PressureInsight.self
            )
            headline = response.content.headline
            guidance = response.content.guidance
            confidence = InsightConfidence(rawValue: response.content.confidence.lowercased()) ?? .low
        } catch {
            print("[Intelligence] Generation failed: \(error.localizedDescription)")
            if headline == nil {
                unavailableReason = "Couldn't generate feedback right now — will retry when the trend changes."
            }
        }
    }
}
