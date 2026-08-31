//
//  StormScopeApp.swift
//  StormScope
//
//  Created by Rork on July 1, 2026.
//

import SwiftUI
import BackgroundTasks
import RevenueCat

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundBarometerService.shared.register()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundBarometerService.shared.schedule()
    }
}

@main
struct StormScopeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // RevenueCat must be configured exactly once, at launch. The Test
        // Store key powers development purchases; the App Store key ships.
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatAPIKey.current)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
