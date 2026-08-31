import Foundation

/// RevenueCat public SDK keys. These are *public by design* — RevenueCat
/// public keys are embedded in every client bundle and only identify the
/// app to the RevenueCat API (no secret material).
///
/// Preferred source is the generated `Config.EXPO_PUBLIC_REVENUECAT_*`;
/// those keys are embedded here as a resilient fallback because the
/// generated config may lag behind newly registered environment variables.
enum RevenueCatAPIKey {
    /// Test Store / development purchases.
    static let test = "test_yZgFNHTitIBszRIwGmAyFWbqFpm"
    /// iOS App Store / production purchases.
    static let appStore = "appl_OmHobMMQDwPhoAGVfCqnEawxgsQ"

    /// The key to configure the SDK with for the current build.
    static var current: String {
        #if DEBUG
        return test
        #else
        return appStore
        #endif
    }
}
