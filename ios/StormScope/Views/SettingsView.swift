import SwiftUI

/// iOS-native settings sheet: unit system picker, notifications and
/// background monitoring, station calibration, data management with
/// destructive confirmation, and privacy/about details.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: DashboardViewModel
    let readingsCount: Int
    let onDeleteData: () -> Void

    @State private var isConfirmingDelete = false
    @State private var didDeleteData = false
    @State private var didCalibrate = false

    var body: some View {
        NavigationStack {
            Form {
                if !DeviceCapability.hasBarometer {
                    noBarometerNotice
                }
                unitsSection
                notificationsSection
                calibrationSection
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

            Toggle(isOn: $settings.mslpEnabled) {
                Label("Mean Sea Level Pressure (MSLP)", systemImage: "globe.americas.fill")
            }
            .disabled(!DeviceCapability.hasBarometer)
            .listRowBackground(Theme.panel)
        } header: {
            Text("Measurement Units")
        } footer: {
            if settings.mslpEnabled {
                Text("Pressure is adjusted to sea level using GPS altitude and surface temperature. This makes readings directly comparable to official NWS station reports regardless of your elevation.\n\nTemperature, wind, and distance follow the Metric / Imperial toggle. Pressure units are set independently.")
            } else {
                Text("Station pressure varies with altitude — expect readings ~1.2 hPa lower for every 100 m of elevation. Enable MSLP to normalize to sea level.\n\nTemperature, wind, and distance follow the Metric / Imperial toggle. Pressure units are set independently.")
            }
        }
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
                Text("Storm notifications fire when your barometer detects a rapid pressure drop. Tornado alerts are time-sensitive and relay official NWS warnings. Background monitoring uses significant location changes to keep readings fresh while the app is closed -- your location never leaves the device.")
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
            Text("StormScope stores your barometer history only on this device. Nothing is uploaded -- deleting removes it permanently.")
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
                Link(destination: URL(string: "https://stormscope.xyz/privacy")!) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .listRowBackground(Theme.panel)

                Link(destination: URL(string: "https://stormscope.xyz/terms")!) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .listRowBackground(Theme.panel)
            } header: {
                Text("Legal")
            }
        }
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
    SettingsView(viewModel: DashboardViewModel(), readingsCount: 214, onDeleteData: {})
}
