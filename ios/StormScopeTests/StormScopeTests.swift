//
//  StormScopeTests.swift
//  StormScopeTests
//
//  Regression tests for the corroboration engine: StormAssessment level
//  buckets, corroboration escalation, TornadoSignature thresholds, and the
//  shared widget snapshot payload.
//

import Testing
import Foundation
@testable import StormScope

struct StormScopeTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    // MARK: - Helpers

    /// Linear series ending at `now`, one sample per minute over `minutes`,
    /// producing exactly `ratePerHour` (hPa/hour) as the regression slope.
    private func readings(ratePerHour: Double, minutes: Int = 61, now: Date) -> [PressureReading] {
        (0..<minutes).map { i in
            let minutesAgo = Double(minutes - 1 - i)
            return PressureReading(
                timestamp: now.addingTimeInterval(-minutesAgo * 60),
                hPa: 1013.0 - ratePerHour * minutesAgo / 60.0
            )
        }
    }

    /// Evenly spaced series spanning `spanMinutes` ending at `now` with a
    /// total pressure change of `drop` (negative = falling).
    private func tornadoReadings(drop: Double, spanMinutes: Double = 10, samples: Int = 5, now: Date) -> [PressureReading] {
        (0..<samples).map { i in
            let fraction = Double(i) / Double(samples - 1)
            return PressureReading(
                timestamp: now.addingTimeInterval(-spanMinutes * (1 - fraction) * 60),
                hPa: 1010.0 + drop * fraction
            )
        }
    }

    /// Alternating ±0.4 hPa minute-to-minute series — sustained sensor-scale
    /// "pumping" that should register via the volatility (jitter) path.
    private func jitterReadings(now: Date) -> [PressureReading] {
        (0...30).map { i in
            PressureReading(
                timestamp: now.addingTimeInterval(Double(30 - i) * -60),
                hPa: i % 2 == 0 ? 1010.2 : 1009.8
            )
        }
    }

    // MARK: - StormAssessment: slope buckets

    @Test func steadyPressureYieldsSteadyLevel() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: 0, now: now), now: now)
        #expect(assessment.level == .steady)
        #expect(!assessment.escalatedByCorroboration)
    }

    @Test func risingPressureYieldsClearingLevel() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: 1.0, now: now), now: now)
        #expect(assessment.level == .rising)
    }

    @Test func moderateFallYieldsChangeComing() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: -1.0, now: now), now: now)
        #expect(assessment.level == .falling)
    }

    @Test func strongFallYieldsStormWatch() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: -2.0, now: now), now: now)
        #expect(assessment.level == .stormLikely)
    }

    @Test func severeFallYieldsFrontImminent() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: -3.2, now: now), now: now)
        #expect(assessment.level == .frontImminent)
    }

    @Test func slopeBoundariesSeparateBuckets() {
        #expect(StormAssessment.assess(readings: readings(ratePerHour: -0.6, now: now), now: now).level == .steady)
        #expect(StormAssessment.assess(readings: readings(ratePerHour: -0.7, now: now), now: now).level == .falling)
        #expect(StormAssessment.assess(readings: readings(ratePerHour: -1.5, now: now), now: now).level == .stormLikely)
        #expect(StormAssessment.assess(readings: readings(ratePerHour: -3.0, now: now), now: now).level == .stormLikely)
    }

    @Test func shortHistoryStaysInCollecting() {
        // 10 minutes of data is below the 15-minute slope requirement.
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: -2.0, minutes: 10, now: now), now: now)
        #expect(assessment.level == .collecting)
        #expect(assessment.ratePerHour == nil)
    }

    // MARK: - StormAssessment: windows & overrides

    @Test func oneHourDeltaMatchesSlope() {
        let assessment = StormAssessment.assess(readings: readings(ratePerHour: -1.0, now: now), now: now)
        #expect(assessment.delta1h != nil)
        #expect(abs(assessment.delta1h! - (-1.0)) < 0.01)
        // Only ~60 minutes of history exists, so the 6-hour window is empty.
        #expect(assessment.delta6h == nil)
    }

    @Test func sustainedThreeHourDropEscalatesDespiteFlatRecentHour() {
        var list: [PressureReading] = []
        // 1016 → 1010 across 120 minutes, then flat for the final hour.
        for m in stride(from: 180, through: 61, by: -1) {
            list.append(PressureReading(
                timestamp: now.addingTimeInterval(Double(-m) * 60),
                hPa: 1010.0 + Double(m - 60) * 0.05
            ))
        }
        for m in stride(from: 60, through: 0, by: -1) {
            list.append(PressureReading(timestamp: now.addingTimeInterval(Double(-m) * 60), hPa: 1010.0))
        }
        let assessment = StormAssessment.assess(readings: list, now: now)
        #expect(assessment.level == .stormLikely)
        #expect(abs(assessment.delta3h! - (-6.0)) < 0.01)
        #expect(!assessment.escalatedByCorroboration)
    }

    // MARK: - StormAssessment: corroboration fusion

    @Test func corroborationEscalatesGenuineFallOneTier() {
        let assessment = StormAssessment.assess(
            readings: readings(ratePerHour: -1.2, now: now),
            corroborators: ["station gusts 70 km/h", "close-range lightning (4 strikes/hr)"],
            now: now
        )
        #expect(assessment.level == .stormLikely)
        #expect(assessment.escalatedByCorroboration)
    }

    @Test func mildFallIsNotEscalated() {
        // Falling level, but the fall is slower than the -1.0 hPa/h gate.
        let assessment = StormAssessment.assess(
            readings: readings(ratePerHour: -0.7, now: now),
            corroborators: ["a", "b"],
            now: now
        )
        #expect(assessment.level == .falling)
        #expect(!assessment.escalatedByCorroboration)
    }

    @Test func steadyBarometerIsNeverEscalated() {
        let assessment = StormAssessment.assess(
            readings: readings(ratePerHour: 0, now: now),
            corroborators: ["a", "b", "c"],
            now: now
        )
        #expect(assessment.level == .steady)
        #expect(!assessment.escalatedByCorroboration)
    }

    @Test func singleCorroboratorIsNotEnough() {
        let assessment = StormAssessment.assess(
            readings: readings(ratePerHour: -1.2, now: now),
            corroborators: ["close-range lightning (5 strikes/hr)"],
            now: now
        )
        #expect(assessment.level == .falling)
        #expect(!assessment.escalatedByCorroboration)
    }

    // MARK: - TornadoSignature: windows & thresholds

    @Test func tooFewSamplesIsInsufficientData() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -1.3, samples: 3, now: now), now: now)
        #expect(signature.status == .insufficientData)
        #expect(signature.drop10m == nil)
    }

    @Test func tooShortSpanIsInsufficientData() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -1.3, spanMinutes: 4, now: now), now: now)
        #expect(signature.status == .insufficientData)
    }

    @Test func smallDropIsQuiet() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -0.1, now: now), now: now)
        #expect(signature.status == .quiet)
        #expect(signature.drop10m == -0.1)
    }

    @Test func moderateDropIsElevated() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -0.6, now: now), now: now)
        #expect(signature.status == .elevated)
        #expect(!signature.escalatedByCorroboration)
    }

    @Test func extremeDropIsSignature() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -1.3, now: now), now: now)
        #expect(signature.status == .signature)
    }

    // MARK: - TornadoSignature: instability tightening

    @Test func highCAPETightensThresholdToSignature() {
        let withCAPE = TornadoSignature.analyze(readings: tornadoReadings(drop: -0.85, now: now), cape: 2500, now: now)
        let withoutCAPE = TornadoSignature.analyze(readings: tornadoReadings(drop: -0.85, now: now), now: now)
        #expect(withCAPE.status == .signature)
        #expect(withoutCAPE.status == .elevated)
        #expect(withCAPE.isAtmosphereUnstable)
    }

    @Test func negativeLiftedIndexTightensThresholdToSignature() {
        let signature = TornadoSignature.analyze(readings: tornadoReadings(drop: -0.85, now: now), liftedIndex: -5, now: now)
        #expect(signature.status == .signature)
    }

    // MARK: - TornadoSignature: corroboration fusion

    @Test func corroborationEscalatesQuietToElevated() {
        let signature = TornadoSignature.analyze(
            readings: tornadoReadings(drop: -0.35, now: now),
            lightningStrikeCount: 3,
            observedGustKmh: 70,
            now: now
        )
        #expect(signature.status == .elevated)
        #expect(signature.escalatedByCorroboration)
        #expect(signature.corroborators.count == 2)
    }

    @Test func corroborationEscalatesElevatedToSignature() {
        let signature = TornadoSignature.analyze(
            readings: tornadoReadings(drop: -0.9, now: now),
            lightningStrikeCount: 3,
            observedGustKmh: 70,
            now: now
        )
        #expect(signature.status == .signature)
        #expect(signature.escalatedByCorroboration)
    }

    @Test func singleCorroboratorDoesNotEscalate() {
        let signature = TornadoSignature.analyze(
            readings: tornadoReadings(drop: -0.35, now: now),
            lightningStrikeCount: 3,
            now: now
        )
        #expect(signature.status == .quiet)
        #expect(!signature.escalatedByCorroboration)
    }

    @Test func spcTornadoProbabilityCountsAsCorroborator() {
        let signature = TornadoSignature.analyze(
            readings: tornadoReadings(drop: -0.35, now: now),
            observedGustKmh: 70,
            spcTornadoProbability: 5,
            now: now
        )
        #expect(signature.status == .elevated)
        #expect(signature.escalatedByCorroboration)
    }

    // MARK: - TornadoSignature: volatility path & window bounds

    @Test func sustainedJitterIsElevatedEvenWithFlatDrop() {
        let signature = TornadoSignature.analyze(readings: jitterReadings(now: now), now: now)
        #expect(signature.status == .elevated)
        #expect(signature.drop10m == 0)
        #expect((signature.volatility ?? 0) >= 0.15)
    }

    @Test func futureReadingsAreExcluded() {
        var list = tornadoReadings(drop: -1.3, now: now)
        list.append(PressureReading(timestamp: now.addingTimeInterval(120), hPa: 1015.0))
        let signature = TornadoSignature.analyze(readings: list, now: now)
        #expect(signature.status == .signature)
        #expect(signature.drop10m == -1.3)
    }

    // MARK: - Shared widget snapshot

    @Test func widgetSnapshotDecodesLegacyPayloadWithoutAlertCount() throws {
        let json = """
        {"pressureHPa":1012.5,"ratePerHour":-0.9,"delta1h":-0.9,"levelRaw":3,"levelTitle":"Change Coming","sparkline":[],"usesImperial":false,"updatedAt":650000000}
        """
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.pressureHPa == 1012.5)
        #expect(snapshot.alertCount == nil)
    }

    @Test func widgetSnapshotRoundTripsWithAlertCount() throws {
        let snapshot = WidgetSnapshot(
            pressureHPa: 1009.1,
            ratePerHour: -2.2,
            delta1h: -2.1,
            levelRaw: 4,
            levelTitle: "Storm Watch",
            sparkline: [1011, 1010, 1009.1],
            usesImperial: true,
            alertCount: 2,
            updatedAt: now
        )
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.alertCount == 2)
        #expect(decoded.levelRaw == 4)
    }

    // MARK: - ProAccess: trial countdown & gating

    /// Fresh first launch: trial runs the full 7 days and unlocks everything.
    @Test func freshTrialIsActiveWithSevenDaysRemaining() {
        let access = ProAccess(
            isPremium: false,
            trialEndDate: ProAccess.trialEnd(from: now),
            now: now
        )
        #expect(access.isTrialActive)
        #expect(access.trialDaysRemaining == 7)
        #expect(access.isUnlocked)
    }

    /// Partial days round up so the banner never understates access.
    @Test func trialDaysRoundUpToWholeDays() {
        let twoAndAHalf = ProAccess(
            isPremium: false,
            trialEndDate: now.addingTimeInterval(2.5 * 24 * 3600),
            now: now
        )
        #expect(twoAndAHalf.trialDaysRemaining == 3)

        let exactlyTwo = ProAccess(
            isPremium: false,
            trialEndDate: now.addingTimeInterval(2 * 24 * 3600),
            now: now
        )
        #expect(exactlyTwo.trialDaysRemaining == 2)
    }

    /// One second past the deadline the trial locks and the gate closes.
    @Test func expiredTrialLocksAllGatedFeatures() {
        let access = ProAccess(
            isPremium: false,
            trialEndDate: now.addingTimeInterval(-1),
            now: now
        )
        #expect(!access.isTrialActive)
        #expect(!access.isUnlocked)
        #expect(access.trialDaysRemaining == 0)
    }

    /// The lifetime purchase overrides an expired trial permanently.
    @Test func premiumOverridesExpiredTrial() {
        let access = ProAccess(
            isPremium: true,
            trialEndDate: now.addingTimeInterval(-1),
            now: now
        )
        #expect(!access.isTrialActive)
        #expect(access.isUnlocked)
    }

    /// Trial deadline lands exactly on start + 7 days.
    @Test func trialEndIsExactlySevenDaysFromStart() {
        #expect(ProAccess.trialEnd(from: now).timeIntervalSince(now) == ProAccess.trialDuration)
    }

    /// Boundary: at the exact trial deadline the gate is closed (strict `<`).
    @Test func trialIsClosedAtExactDeadline() {
        let access = ProAccess(
            isPremium: false,
            trialEndDate: now,
            now: now
        )
        #expect(!access.isTrialActive)
        #expect(!access.isUnlocked)
    }

    // MARK: - Legal links

    /// In-app Privacy, Terms, Support, and Contact must open the COPYCRAWLER hub.
    @Test func legalLinksPointAtCopycrawlerHub() {
        #expect(LegalLinks.privacy.absoluteString == "https://copycrawler-hub.lovable.app/privacy")
        #expect(LegalLinks.terms.absoluteString == "https://copycrawler-hub.lovable.app/terms")
        #expect(LegalLinks.support.absoluteString == "https://copycrawler-hub.lovable.app/support")
        #expect(LegalLinks.contact.absoluteString == "https://copycrawler-hub.lovable.app/contact")
        #expect(LegalLinks.privacy.scheme == "https")
        #expect(LegalLinks.terms.scheme == "https")
        #expect(LegalLinks.support.scheme == "https")
        #expect(LegalLinks.contact.scheme == "https")
    }
}
