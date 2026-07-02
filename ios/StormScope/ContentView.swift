//
//  ContentView.swift
//  StormScope
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var isShowingInfo = false
    @State private var isShowingSettings = false
    @State private var isShowingAlerts = false
    @State private var isShowingDisclaimer = false

    private var units: UnitSystem {
        viewModel.settings.unitSystem
    }

    private var pressureMode: PressureDisplayMode {
        viewModel.settings.pressureDisplayMode
    }

    private var assessment: StormAssessment {
        viewModel.assessment
    }

    var body: some View {
        @Bindable var settings = viewModel.settings
        return ZStack {
            background
            ScrollView {
                VStack(spacing: 18) {
                    // Status: overall level + official alerts.
                    header
                    StormBannerView(level: assessment.level)
                    AlertsStripView(
                        alerts: viewModel.alerts,
                        errorMessage: viewModel.alertsError,
                        isLoading: viewModel.isLoadingAlerts,
                        onOpen: { isShowingAlerts = true }
                    )
                    if !DeviceCapability.hasBarometer {
                        demoBanner
                    }

                    // Core instrument: live pressure, tendency, and history.
                    PressureGaugeView(
                        pressure: viewModel.displayPressure,
                        level: assessment.level,
                        ratePerHour: assessment.ratePerHour,
                        pressureMode: pressureMode,
                        isCalibrated: viewModel.settings.isCalibrated,
                        isMSLP: viewModel.settings.mslpEnabled
                    )
                    .padding(.vertical, 4)
                    TendencyRowView(delta1h: assessment.delta1h, delta3h: assessment.delta3h, delta6h: assessment.delta6h, pressureMode: pressureMode)
                    TrendChartView(readings: viewModel.displayReadings, tint: assessment.level.tint, pressureMode: pressureMode)

                    // Threat detection: micro-drop analysis + lightning EMP.
                    TornadoModeView(
                        isEnabled: $viewModel.isTornadoModeEnabled,
                        signature: viewModel.tornadoSignature,
                        hasTornadoWarning: viewModel.hasTornadoWarning,
                        hasTornadoWatch: viewModel.hasTornadoWatch,
                        pressureMode: pressureMode,
                        isSimulated: viewModel.barometer.isSimulated
                    )
                    if DeviceCapability.hasMagnetometer && viewModel.settings.lightningDetectionEnabled {
                        LightningCardView(magnetometer: viewModel.magnetometer)
                    }
                    AIInsightCardView(
                        contextSummary: viewModel.intelligenceContext,
                        refreshKey: viewModel.intelligenceKey,
                        fallbackText: assessment.level.detail
                    )

                    // Situational awareness: radar/satellite map + SPC outlook.
                    RadarCardView(
                        latitude: viewModel.location.latitude,
                        longitude: viewModel.location.longitude,
                        alerts: viewModel.alerts,
                        layerMode: $settings.radarLayerMode,
                        radarStatus: viewModel.radarStatus
                    )
                    OutlookCardView(
                        outlooks: viewModel.outlooks,
                        isLoading: viewModel.isLoadingOutlook
                    )

                    // Verification: station map + official station readings.
                    StationsMapCardView(
                        stations: viewModel.stations,
                        deviceLatitude: viewModel.location.latitude,
                        deviceLongitude: viewModel.location.longitude,
                        devicePressure: viewModel.displayPressure,
                        pressureMode: pressureMode,
                        isLoading: viewModel.isLoadingStations,
                        errorMessage: viewModel.stationsError,
                        isExpanded: $settings.stationsMapExpanded
                    )
                    StationsCardView(
                        stations: viewModel.stations,
                        devicePressure: viewModel.displayPressure,
                        units: units,
                        pressureMode: pressureMode,
                        isLoading: viewModel.isLoadingStations,
                        errorMessage: viewModel.stationsError
                    )
                    WeatherStripView(
                        weather: viewModel.weather,
                        sensorDelta: viewModel.sensorVsStationDelta,
                        units: units,
                        pressureMode: pressureMode,
                        isMSLP: viewModel.settings.mslpEnabled,
                        isLoading: viewModel.isLoadingWeather,
                        errorMessage: viewModel.weatherError
                    )
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .refreshable {
                await viewModel.refreshRemote()
            }
        }
        .task {
            viewModel.start()
        }
        .task {
            // Show the safety disclaimer on first launch only.
            if !viewModel.settings.hasAcceptedDisclaimer {
                try? await Task.sleep(for: .seconds(0.6))
                isShowingDisclaimer = true
            }
        }
        .sheet(isPresented: $isShowingDisclaimer) {
            DisclaimerSheet(onAccept: {
                viewModel.settings.hasAcceptedDisclaimer = true
                isShowingDisclaimer = false
            })
        }
        .task(id: viewModel.location.coordinateKey) {
            await viewModel.refreshRemote()
        }
        .sheet(isPresented: $isShowingInfo) {
            InfoSheetView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingAlerts) {
            NavigationStack {
                ScrollView {
                    AlertsCardView(
                        alerts: viewModel.alerts,
                        errorMessage: viewModel.alertsError,
                        isLoading: viewModel.isLoadingAlerts
                    )
                    .padding(16)
                }
                .background(Theme.ink)
                .navigationTitle("NWS Alerts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { isShowingAlerts = false }
                            .fontWeight(.semibold)
                            .tint(Theme.cyan)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                viewModel: viewModel,
                readingsCount: viewModel.barometer.readings.count,
                onDeleteData: { viewModel.deleteAllData() }
            )
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Layers

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.inkDeep, Theme.ink],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [assessment.level.tint.opacity(0.14), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .animation(.easeInOut(duration: 0.8), value: assessment.level)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("StormScope")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    HStack(spacing: 5) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(locationLabel)
                            .lineLimit(1)
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Button {
                    isShowingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("How it works")
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Settings")
            }

            if viewModel.location.isApproximate {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.system(size: 9))
                    Text("Network-based location — enable Location access for precise data.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.amber.opacity(0.9))
            }

            HStack(spacing: 8) {
                sensorChip
                if let altitude = viewModel.location.altitude {
                    HStack(spacing: 4) {
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 9))
                        Text(String(format: "%.0f m", altitude))
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Text(Date().formatted(.dateTime.weekday(.wide).day().month()))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var sensorChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(sensorChipColor)
                .frame(width: 7, height: 7)
            Text(sensorChipLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(1)
                .foregroundStyle(sensorChipColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(sensorChipColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var sensorChipColor: Color {
        if !DeviceCapability.hasBarometer { return Theme.amber }
        if viewModel.barometer.isSimulated { return Theme.amber }
        return Theme.green
    }

    private var sensorChipLabel: String {
        if !DeviceCapability.hasBarometer { return "DEMO MODE" }
        if viewModel.barometer.isSimulated { return "SIMULATED FEED" }
        return "LIVE SENSOR"
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !DeviceCapability.hasBarometer || viewModel.barometer.isSimulated {
                VStack(spacing: 6) {
                    if !DeviceCapability.hasBarometer {
                        Text("This device has no built-in barometer. StormScope is showing a demo pressure simulation so you can explore the app. Install on an iPhone 6 or later for real on-device pressure readings.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.amber.opacity(0.9))
                            .multilineTextAlignment(.center)
                    } else {
                        Text("The barometer is available but a demo feed is active. Real readings begin when the sensor starts.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            Text("Early-warning aid — always follow official severe weather alerts.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary.opacity(0.8))
        }
        .padding(.top, 6)
        .padding(.horizontal, 8)
    }

    private var demoBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.gen1.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.amber)
                Text("No barometer detected on this device")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.amber)
            }
            Text("Pressure gauge, trends, and tornado signature analysis are simulated for demonstration only. NWS alerts and weather data remain live.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Theme.amber.opacity(0.08))
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.amber.opacity(0.2), lineWidth: 1))
    }

    private var locationLabel: String {
        if let name = viewModel.location.placeName {
            if viewModel.location.isApproximate { return "\(name) (approximate)" }
            return viewModel.location.isFallback ? "\(name) (default)" : name
        }
        return "Locating…"
    }
}

#Preview {
    ContentView()
}
