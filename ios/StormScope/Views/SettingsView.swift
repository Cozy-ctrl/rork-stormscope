import SwiftUI
import UniformTypeIdentifiers

/// iOS-native settings sheet: unit system picker, notifications and
/// background monitoring, station calibration, data management with
/// destructive confirmation, data export, and privacy/about details.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: DashboardViewModel
    let store: StoreViewModel
    let readingsCount: Int
    let onDeleteData: () -> Void

    @State private var isConfirmingDelete = false
    @State private var didDeleteData = false
    @State private var didCalibrate = false
    @State private var isShowingShareSheet = false
    @State private var isShowingPaywall = false
    @State private var exportItem: Any? = nil

    var body: some View {
        NavigationStack {
            Form {
                if !DeviceCapability.hasBarometer {
                    noBarometerNotice
                }
                unitsSection
                proSection
                notificationsSection
                calibrationSection
                dashboardSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.cyan)
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let item = exportItem {
                    ShareSheet(activityItems: [item])
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView(store: store)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.success, trigger: didDeleteData)
        .sensoryFeedback(.success, trigger: didCalibrate)
        .task {
            await viewModel.notifier.refreshAuthorizationStatus()
        }
    }

    // MARK: - No-barometer notice

    private var noBarometerNotice: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.gen1.slash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.amber)
                    Text("No Barometer Available")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.amber)
                }
                Text("This device lacks a built-in pressure sensor. Barometer-dependent features — background monitoring, sensor calibration, and pressure-triggered notifications — are disabled. All other features (NWS alerts, radar, SPC outlooks, weather data) remain fully live.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Theme.amber.opacity(0.08))
        }
    }

    // MARK: - Sections

    private var unitsSection: some View {
        @Bindable var settings = viewModel.settings
        return Section {
            Picker("Temperature & Wind", selection: $settings.unitSystem) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.title).tag(system)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Theme.panel)

            Picker("Pressure", selection: $settings.pressureDisplayMode) {
                ForEach(PressureDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .listRowBackground(Theme.panel)

            Picker("Chart", selection: $settings.chartPressureUnit) {
                Text("hPa").tag(PressureDisplayMode.hPa)
                Text("inHg").tag(PressureDisplayMode.inHg)
            }
            .listRowBackground(Theme.panel)

            Toggle(isOn: $settings.mslpEnabled) {
                Label("Mean Sea Level Pressure (MSLP)", systemImage: "globe.americas.fill")
            }
            .disabled(!DeviceCapability.hasBarometer)
            .listRowBackground(Theme.panel)
        } header: {
            Text("Measurement Units")
        } footer: {
            if settings.mslpEnabled {
                Text("Pressure is adjusted to sea level using GPS altitude and surface temperature. This makes readings directly comparable to official NWS station reports regardless of your elevation.\n\nTemperature, wind, and distance follow the Metric / Imperial toggle. Pressure and chart units are set independently.")
            } else {
                Text("Station pressure varies with altitude — expect readings ~1.2 hPa lower for every 100 m of elevation. Enable MSLP to normalize to sea level.\n\nTemperature, wind, and distance follow the Metric / Imperial toggle. Pressure and chart units are set independently.")
            }
        }
    }

    // MARK: - Pro

    /// Ownership, trial countdown, and unlock/restore entry points.
    private var proSection: some View {
        Section {
            if store.isPremium {
                LabeledContent {
                    Text("Active")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.green)
                } label: {
                    Label("StormScope Pro", systemImage: "checkmark.seal.fill")
                }
                .listRowBackground(Theme.panel)
            } else {
                LabeledContent {
                    if store.isTrialActive {
                        Text("\(store.trialDaysRemaining) day\(store.trialDaysRemaining == 1 ? "" : "s") left")
                            .foregroundStyle(Theme.textSecondary)
                            .monospacedDigit()
                    } else {
                        Text("Ended")
                            .foregroundStyle(Theme.amber)
                    }
                } label: {
                    Label("Full-Access Trial", systemImage: "hourglass")
                }
                .listRowBackground(Theme.panel)

                Button {
                    isShowingPaywall = true
                } label: {
                    Label("Unlock StormScope Pro", systemImage: "lock.open.fill")
                }
                .listRowBackground(Theme.panel)
            }

            Button {
                Task { await store.restore() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise.circle")
            }
            .listRowBackground(Theme.panel)
        } header: {
            Text("StormScope Pro")
        } footer: {
            Text("Pro unlocks Live Feedback, radar & SPC outlook imagery, and data exports with monthly, annual, or one-time lifetime plans. Storm monitoring, NWS alerts, and lightning detection stay free forever.")
        }
        .tint(Theme.cyan)
    }

    private var notificationsSection: some View {
        @Bindable var settings = viewModel.settings
        return Section {
            Toggle(isOn: Binding(
                get: { settings.stormNotificationsEnabled },
                set: { newValue in
                    settings.stormNotificationsEnabled = newValue
                    if newValue { requestNotificationPermission() }
                }
            )) {
                Label("Storm Notifications", systemImage: "cloud.bolt.fill")
            }
            .listRowBackground(Theme.panel)

            Toggle(isOn: Binding(
                get: { settings.tornadoAlertsEnabled },
                set: { newValue in
                    settings.tornadoAlertsEnabled = newValue
                    if newValue { requestNotificationPermission() }
                }
            )) {
                Label("Tornado Warning Alerts", systemImage: "tornado")
            }
            .listRowBackground(Theme.panel)

            Toggle(isOn: Binding(
                get: { settings.backgroundMonitoringEnabled },
                set: { newValue in
                    settings.backgroundMonitoringEnabled = newValue
                    viewModel.applyBackgroundMonitoringSetting()
                }
            )) {
                Label("Background Monitoring", systemImage: "moon.zzz.fill")
            }
            .disabled(!DeviceCapability.hasBarometer)
            .listRowBackground(Theme.panel)

            if !DeviceCapability.hasBarometer {
                Text("Background monitoring requires a device barometer to sample pressure while the app is closed.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .listRowBackground(Theme.panel)
            }

            Toggle(isOn: Binding(
                get: { viewModel.liveActivity.isRunning },
                set: { _ in viewModel.toggleLiveActivity() }
            )) {
                Label("Lock Screen Live Activity", systemImage: "bolt.badge.clock")
            }
            .listRowBackground(Theme.panel)

            Toggle(isOn: Binding(
                get: { settings.lightningDetectionEnabled },
                set: { newValue in
                    settings.lightningDetectionEnabled = newValue
                    viewModel.applyMagnetometerSetting()
                }
            )) {
                Label("Lightning Detection", systemImage: "bolt.fill")
            }
            .disabled(!DeviceCapability.hasMagnetometer)
            .listRowBackground(Theme.panel)

            if !DeviceCapability.hasMagnetometer {
                Text("Lightning detection requires a magnetometer (available on most iPhones since the 3GS).")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .listRowBackground(Theme.panel)
            }

            if viewModel.notifier.isDenied && (settings.stormNotificationsEnabled || settings.tornadoAlertsEnabled) {
                Label("Notifications are turned off for StormScope in iOS Settings.", systemImage: "bell.slash.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.orange)
                    .listRowBackground(Theme.panel)
            }
        } header: {
            Text("Alerts & Monitoring")
        } footer: {
            if !DeviceCapability.hasBarometer {
                Text("Storm and tornado notifications are based on NWS alert data and work without a barometer. Background monitoring is disabled on this device because it requires the pressure sensor.")
            } else {
                Text("Storm notifications fire when your barometer detects a rapid pressure drop. Tornado alerts are time-sensitive and relay official NWS warnings. Lightning detection uses the device magnetometer to sense EMP spikes from nearby strikes — turn this off to save battery in magnetically noisy environments. Background monitoring uses significant location changes to keep readings fresh while the app is closed — your location never leaves the device.")
            }
        }
        .tint(Theme.cyan)
    }

    private var calibrationSection: some View {
        Section {
            if !DeviceCapability.hasBarometer {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Sensor Calibration Unavailable", systemImage: "scope")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Calibration requires a built-in barometer to compare your device readings against nearby NWS station data.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.panel)
            } else if viewModel.settings.isCalibrated {
                LabeledContent {
                    Text(viewModel.settings.pressureDisplayMode.deltaFine(viewModel.settings.calibrationOffset))
                        .foregroundStyle(Theme.green)
                        .monospacedDigit()
                } label: {
                    Label("Active Offset", systemImage: "checkmark.seal.fill")
                }
                .listRowBackground(Theme.panel)

                if let station = viewModel.settings.calibrationStationID {
                    LabeledContent {
                        Text(station)
                            .foregroundStyle(Theme.textSecondary)
                    } label: {
                        Label("Aligned To", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .listRowBackground(Theme.panel)
                }

                Button {
                    viewModel.settings.clearCalibration()
                } label: {
                    Label("Clear Calibration", systemImage: "arrow.uturn.backward")
                }
                .listRowBackground(Theme.panel)
            } else {
                Button {
                    if viewModel.calibrateToNearestStation() {
                        didCalibrate.toggle()
                    }
                } label: {
                    Label("Calibrate to Nearest Station", systemImage: "scope")
                }
                .disabled(viewModel.calibrationCandidate == nil || viewModel.barometer.currentPressure == nil)
                .listRowBackground(Theme.panel)

                if viewModel.calibrationCandidate == nil {
                    Text("Waiting for a nearby NWS station report -- pull to refresh on the dashboard first.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .listRowBackground(Theme.panel)
                }
            }
        } header: {
            Text("Sensor Calibration")
        } footer: {
            if !DeviceCapability.hasBarometer {
                Text("Sensor calibration is available on iPhones with a built-in barometer (iPhone 6 and later).")
            } else {
                Text("Aligns your barometer to the nearest NWS station reading, zeroing out factory variance between devices. Storm detection always uses the raw trend, so calibration only changes the displayed numbers.")
            }
        }
        .tint(Theme.cyan)
    }

    private var dashboardSection: some View {
        Section {
            Button {
                viewModel.settings.resetDashboardSections()
            } label: {
                Label("Reset Collapsed Sections", systemImage: "rectangle.expand.vertical")
            }
            .listRowBackground(Theme.panel)
        } header: {
            Text("Dashboard")
        } footer: {
            Text("Re-expands the radar, local conditions, and station sections on the main screen.")
        }
        .tint(Theme.cyan)
    }

    private var dataSection: some View {
        Section {
            LabeledContent {
                Text("\(readingsCount) readings")
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            } label: {
                Label("Pressure History", systemImage: "waveform.path.ecg")
            }
            .listRowBackground(Theme.panel)

            Button {
                handleExportTap(exportCSV)
            } label: {
                Label("Export Pressure Data (CSV)", systemImage: "tablecells")
            }
            .disabled(readingsCount == 0)
            .listRowBackground(Theme.panel)

            Button {
                handleExportTap(exportJSON)
            } label: {
                Label("Export Full Report (JSON)", systemImage: "doc.text.fill")
            }
            .listRowBackground(Theme.panel)

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label("Delete All Data", systemImage: "trash")
                    .foregroundStyle(Theme.red)
            }
            .listRowBackground(Theme.panel)
            .confirmationDialog(
                "Delete all data?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete All Data", role: .destructive) {
                    onDeleteData()
                    didDeleteData.toggle()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your recorded pressure history and resets all preferences. This cannot be undone.")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("StormScope stores your barometer history only on this device. Nothing is uploaded — deleting removes it permanently. Exporting requires StormScope Pro after the free trial.")
        }
    }

    private var aboutSection: some View {
        Group {
            Section {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(Theme.textSecondary)
                } label: {
                    Label("Version", systemImage: "info.circle")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Text("api.weather.gov")
                        .foregroundStyle(Theme.textSecondary)
                } label: {
                    Label("Alerts & Stations", systemImage: "antenna.radiowaves.left.and.right")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Text("spc.noaa.gov")
                        .foregroundStyle(Theme.textSecondary)
                } label: {
                    Label("Severe Outlook", systemImage: "chart.xyaxis.line")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Text("Open-Meteo")
                        .foregroundStyle(Theme.textSecondary)
                } label: {
                    Label("Weather Model", systemImage: "cloud.sun")
                }
                .listRowBackground(Theme.panel)
            } header: {
                Text("About")
            } footer: {
                Text("StormScope is an early-warning aid, not a replacement for official severe weather alerts.")
            }

            Section {
                LabeledContent {
                    Image(systemName: DeviceCapability.hasBarometer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(DeviceCapability.hasBarometer ? Theme.green : Theme.textTertiary)
                } label: {
                    Label("Barometer", systemImage: "sensor")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Image(systemName: DeviceCapability.hasMagnetometer ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(DeviceCapability.hasMagnetometer ? Theme.green : Theme.textTertiary)
                } label: {
                    Label("Magnetometer", systemImage: "bolt.fill")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Image(systemName: DeviceCapability.supportsAppleIntelligenceAPI ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(DeviceCapability.supportsAppleIntelligenceAPI ? Theme.green : Theme.textTertiary)
                } label: {
                    Label("Apple Intelligence", systemImage: "apple.intelligence")
                }
                .listRowBackground(Theme.panel)

                LabeledContent {
                    Image(systemName: DeviceCapability.hasLiveActivities ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(DeviceCapability.hasLiveActivities ? Theme.green : Theme.textTertiary)
                } label: {
                    Label("Live Activities", systemImage: "bolt.badge.clock")
                }
                .listRowBackground(Theme.panel)
            } header: {
                Text("Device Capabilities")
            } footer: {
                Text("Features are automatically adjusted to match this device's hardware and OS version.")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("StormScope does not collect, store, or transmit any personal data. All sensor readings, location data, and AI analysis stay on your device. See the Privacy Nutrition Label above for details required by Apple.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.panel)
            } header: {
                Text("Privacy & Legal")
            } footer: {
                Text("Full privacy policy and terms of service are linked in the App Store listing.")
            }
        }
    }

    // MARK: - Export

    /// Exports are a gated feature: opens the paywall instead when locked.
    private func handleExportTap(_ action: @escaping () -> Void) {
        guard store.isUnlocked else {
            isShowingPaywall = true
            return
        }
        action()
    }

    private func exportCSV() {
        let readings = viewModel.barometer.readings
        guard !readings.isEmpty else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var csv = "timestamp,hPa\r\n"
        for reading in readings {
            let ts = formatter.string(from: reading.timestamp)
            csv += "\(ts),\(reading.hPa)\r\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("StormScope_PressureData_\(dateStamp()).csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        exportItem = fileURL
        isShowingShareSheet = true
    }

    private func exportJSON() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var dict: [String: Any] = [:]
        dict["exportedAt"] = formatter.string(from: Date())
        dict["appVersion"] = appVersion

        // Pressure history
        dict["pressureReadings"] = viewModel.barometer.readings.map { reading -> [String: Any] in
            [
                "timestamp": formatter.string(from: reading.timestamp),
                "hPa": reading.hPa
            ]
        }

        // Current snapshot
        var snapshot: [String: Any] = [:]
        if let pressure = viewModel.displayPressure {
            snapshot["pressure"] = pressure
            snapshot["pressureUnit"] = viewModel.settings.pressureDisplayMode.shorthand
            snapshot["isMSLP"] = viewModel.settings.mslpEnabled
            snapshot["isCalibrated"] = viewModel.settings.isCalibrated
        }
        let assessment = viewModel.assessment
        snapshot["level"] = assessment.level.title
        if let rate = assessment.ratePerHour {
            snapshot["ratePerHour"] = rate
        }
        if let d1 = assessment.delta1h { snapshot["delta1h"] = d1 }
        if let d3 = assessment.delta3h { snapshot["delta3h"] = d3 }
        if let d6 = assessment.delta6h { snapshot["delta6h"] = d6 }
        dict["assessment"] = snapshot

        // Tornado signature
        let sig = viewModel.tornadoSignature
        var tornado: [String: Any] = [
            "status": "\(sig.status)",
            "isAtmosphereUnstable": sig.isAtmosphereUnstable
        ]
        if let drop = sig.drop10m { tornado["drop10m"] = drop }
        if let vol = sig.volatility { tornado["volatility"] = vol }
        dict["tornadoSignature"] = tornado

        // Weather
        if let weather = viewModel.weather {
            dict["weather"] = [
                "temperature": weather.temperature,
                "apparentTemperature": weather.apparentTemperature,
                "humidity": weather.humidity,
                "windSpeed": weather.windSpeed,
                "windGust": weather.windGust as Any,
                "windDirection": weather.windDirection as Any,
                "dewPoint": weather.dewPoint as Any,
                "cloudCover": weather.cloudCover as Any,
                "visibility": weather.visibility as Any,
                "weatherCode": weather.weatherCode,
                "precipitationNow": weather.precipitationNow as Any,
                "precipitationLast24h": weather.precipitationLast24h as Any,
                "cape": weather.cape as Any,
                "liftedIndex": weather.liftedIndex as Any,
                "stationPressure": weather.stationPressure,
                "fetchedAt": formatter.string(from: weather.fetchedAt)
            ]
        }

        // Lightning
        dict["lightning"] = [
            "strikeCount": viewModel.magnetometer.strikeCount,
            "estimatedDistanceKm": viewModel.magnetometer.estimatedDistanceKm as Any,
            "proximity": viewModel.magnetometer.proximityLabel.rawValue
        ]

        // NWS alerts
        dict["alerts"] = viewModel.alerts.map { alert -> [String: Any] in
            [
                "event": alert.properties.event,
                "headline": alert.properties.headline ?? "",
                "severity": alert.properties.severity ?? "",
                "urgency": alert.properties.urgency ?? "",
                "expires": alert.properties.expires.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            ]
        }

        // Station cross-check
        if let agreement = viewModel.stationAgreement {
            dict["stationCrossCheck"] = [
                "stationCount": agreement.count,
                "maxAbsDelta": agreement.maxAbsDelta
            ]
        }
        if let gradient = viewModel.pressureGradient {
            dict["pressureGradient"] = [
                "towardBearingDeg": gradient.towardLowBearingDeg,
                "compassLabel": gradient.compassLabel,
                "magnitudeHPaPer100km": gradient.magnitudeHPaPer100km
            ]
        }

        // Serialize
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("StormScope_FullReport_\(dateStamp()).json")
        try? data.write(to: fileURL)
        exportItem = fileURL
        isShowingShareSheet = true
    }

    private func dateStamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HHmm"
        return df.string(from: Date())
    }

    private func requestNotificationPermission() {
        Task {
            await viewModel.notifier.requestAuthorization()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
}

#Preview {
    SettingsView(viewModel: DashboardViewModel(), store: StoreViewModel(), readingsCount: 214, onDeleteData: {})
}
