import Foundation
import Observation
import RevenueCat

/// Central monetization state: the RevenueCat "premium" entitlement plus the
/// per-device full-access trial. Shared as a single instance from `ContentView`.
///
/// Gating model:
/// - Every feature is free for the first `trialDuration` (3 days per device).
/// - After that, heavy features (AI Insight, radar/SPC outlook imagery, data
///   exports & report sharing) require the one-time "premium" entitlement.
/// - Life-safety basics never lock and never consult this object.
@Observable
@MainActor
final class StoreViewModel {
    static let entitlementID = "premium"
    /// Full-access trial length: 3 days from first launch on this device.
    static let trialDuration: TimeInterval = 3 * 24 * 3600
    private static let trialStartKey = "stormscope.trial.startDate"

    /// True when the one-time lifetime purchase is active.
    private(set) var isPremium = false
    var offerings: Offerings?
    var isLoading = false
    var isPurchasing = false
    var errorMessage: String?

    /// When the trial ends. Recorded on first launch; never reset by
    /// reinstalling the app within the same device backup.
    let trialEndDate: Date

    init() {
        let now = Date()
        if let stored = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date {
            trialEndDate = stored.addingTimeInterval(Self.trialDuration)
        } else {
            UserDefaults.standard.set(now, forKey: Self.trialStartKey)
            trialEndDate = now.addingTimeInterval(Self.trialDuration)
        }

        Task {
            await listenForUpdates()
            await checkStatus()
            await fetchOfferings()
        }
    }

    // MARK: - Derived state

    /// Whether the 3-day full-access trial is still running.
    var isTrialActive: Bool {
        Date() < trialEndDate
    }

    /// Whole days of full access remaining (0 once expired).
    var trialDaysRemaining: Int {
        let remaining = trialEndDate.timeIntervalSinceNow
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / (24 * 3600)))
    }

    /// Master gate for heavy features: paid OR still inside the trial.
    var isUnlocked: Bool {
        isPremium || isTrialActive
    }

    /// Human-readable price of the lifetime package, when the offering loaded.
    var lifetimePrice: String? {
        lifetimePackage?.storeProduct.localizedPriceString
    }

    var lifetimePackage: Package? {
        offerings?.current?.package(identifier: "$rc_lifetime")
            ?? offerings?.current?.availablePackages.first
    }

    // MARK: - RevenueCat

    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    func fetchOfferings() async {
        isLoading = true
        do {
            offerings = try await Purchases.shared.offerings()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func purchase(package: Package) async {
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                apply(result.customerInfo)
            }
        } catch ErrorCode.purchaseCancelledError {
            // StoreKit cancellation — not an error.
        } catch ErrorCode.paymentPendingError {
            // Awaiting parental approval / extra auth — not a failure.
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkStatus() async {
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Offline or unreachable — keep the last known entitlement state.
        }
    }

    private func apply(_ info: CustomerInfo) {
        isPremium = info.entitlements[Self.entitlementID]?.isActive == true
    }
}
