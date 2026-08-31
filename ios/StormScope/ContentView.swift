//
//  ContentView.swift
//  StormScope
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var store = StoreViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingInfo = false
    @State private var isShowingSettings = false
    @State private var isShowingAlerts = false
    @State private var isShowingDisclaimer = false
    @State private var isShowingShareSheet = false
    @State private var isShowingPaywall = false
    /// Built fresh at tap time and presented via `sheet(item:)` so the sheet
    /// can never render before the report content exists.
    @State private var shareReport: ShareReport?

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
                LazyVStack(spacing: 18) {
                    // Status: overall level + official alerts.
                    header
                    if !store.isPremium {
                        TrialBannerView(store: store) { isShowingPaywall = true }
                    }
                    StormBannerView(level: assessment.level)
                    if viewModel.isRapidPollingActive {
                        EventConfirmationCardView(
                            confirmation: viewModel.confirmation,
                            isChecking: viewModel.isCheckingConfirmation,
                            pressureMode: pressureMode,
                            onCheckNow: {
                                Task { await viewModel.runConfirmationCheck() }
                            }
                        )
                    }
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
                    TrendChartView(readings: viewModel.displayReadings, tint: assessment.level.tint, chartUnit: $settings.chartPressureUnit)

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
                    if store.isUnlocked {
                        AIInsightCardView(
                            contextSummary: viewModel.intelligenceContext,
                            refreshKey: viewModel.intelligenceKey,
                            fallbackText: assessment.level.detail
                        )
                    } else {
                        PremiumTeaserCard(
                            icon: "apple.intelligence",
                            title: "Live Feedback",
                            message: "On-device AI turns your pressure trend into plain-language storm guidance.",
                            onUnlock: { isShowingPaywall = true }
                        )
                    }

                    // Situational awareness: radar/satellite map + SPC outlook.
                    DashboardSection(
                        title: "Radar & Outlook",
                        icon: "antenna.radiowaves.left.and.right",
                        tint: Theme.cyan,
                        isLoading: viewModel.isLoadingOutlook,
                        lastUpdated: viewModel.lastOutlookUpdate,
                        isExpanded: $settings.radarSectionExpanded
                    ) {
                        if store.isUnlocked {
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
                        } else {
                            PremiumTeaserCard(
                                icon: "antenna.radiowaves.left.and.right",
                                title: "Radar & SPC Outlook",
                                message: "NEXRAD radar imagery and Storm Prediction Center convective outlooks for your area.",
                                minHeight: 190,
                                onUnlock: { isShowingPaywall = true }
                            )
                        }
                    }

                    // Optics + local conditions + ground-truth observations.
                    DashboardSection(
                        title: "Local Conditions",
                        icon: "cloud.sun.fill",
                        tint: Theme.green,
                        isLoading: viewModel.isLoadingWeather,
                        lastUpdated: viewModel.lastWeatherUpdate,
                        isExpanded: $settings.conditionsSectionExpanded
                    ) {
                        if let rainbow = viewModel.rainbowForecast, rainbow.isDisplayWorthy {
                            RainbowCardView(forecast: rainbow)
                        }
                        WeatherStripView(
                            weather: viewModel.weather,
                            sensorDelta: viewModel.sensorVsStationDelta,
                            units: units,
                            pressureMode: pressureMode,
                            isMSLP: viewModel.settings.mslpEnabled,
                            isLoading: viewModel.isLoadingWeather,
                            errorMessage: viewModel.weatherError
                        )
                        StationWindCardView(
                            stations: viewModel.stations,
                            weather: viewModel.weather,
                            units: units
                        )
                        PrecipCardView(
                            weather: viewModel.weather,
                            stations: viewModel.stations,
                            units: units
                        )
                    }

                    // Verification: official station readings + spatial map + comparison chart.
                    DashboardSection(
                        title: "Station Verification",
                        icon: "checkmark.seal.fill",
                        tint: Theme.amber,
                        isLoading: viewModel.isLoadingStations,
                        skeletonCount: 3,
                        lastUpdated: viewModel.lastStationsUpdate,
                        isExpanded: $settings.stationsSectionExpanded
                    ) {
                        StationsCardView(
                            stations: viewModel.stations,
                            devicePressure: viewModel.displayPressure,
                            units: units,
                            pressureMode: pressureMode,
                            isLoading: viewModel.isLoadingStations,
                            errorMessage: viewModel.stationsError,
                            isExpanded: $settings.stationsListExpanded
                        )
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
                        if !viewModel.stations.isEmpty {
                            StationsChartCardView(
                                stations: viewModel.stations,
                                devicePressure: viewModel.displayPressure,
                                units: units,
                                pressureMode: pressureMode
                            )
                        }
                        if let devicePressure = viewModel.displayPressure, !viewModel.stations.isEmpty {
                            DeviceDeltaCardView(
                                stations: viewModel.stations,
                                devicePressure: devicePressure,
                                deviceLatitude: viewModel.location.latitude,
                                deviceLongitude: viewModel.location.longitude,
                                pressureMode: pressureMode
                            )
                        }
                    }
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .refreshable {
                await viewModel.refreshRemote()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
                    .padding(.bottom, 4)
            }
        }
        .task {
            viewModel.start()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.handleScenePhase(phase)
            // Re-validate the entitlement when returning to the foreground
            // so gating reflects purchases made outside the app.
            if phase == .active {
                Task { await store.checkStatus() }
            }
        }
        .onAppear {
            // Always start with the station map collapsed for a clean dashboard.
            viewModel.settings.stationsMapExpanded = false
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
                store: store,
                readingsCount: viewModel.barometer.readings.count,
                onDeleteData: { viewModel.deleteAllData() }
            )
        }
        .sheet(isPresented: $isShowingPaywall) {
            PaywallView(store: store)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let report = shareReport {
                ShareSheet(activityItems: [report.text])
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Report

    private func buildReportSnapshot() -> String {
        StormReportGenerator.plainTextReport(from: StormReportGenerator.Snapshot(
            date: Date(),
            formattedDate: Date().formatted(date: .long, time: .shortened),
            placeName: viewModel.location.placeName,
            latitude: viewModel.location.latitude,
            longitude: viewModel.location.longitude,
            altitude: viewModel.location.altitude,
            isApproximate: viewModel.location.isApproximate,
            isSimulated: viewModel.barometer.isSimulated,
            hasBarometer: DeviceCapability.hasBarometer,
            pressure: viewModel.displayPressure,
            pressureUnit: viewModel.settings.pressureDisplayMode.shorthand,
            isMSLP: viewModel.settings.mslpEnabled,
            isCalibrated: viewModel.settings.isCalibrated,
            calibrationStation: viewModel.settings.calibrationStationID,
            levelTitle: assessment.level.title,
            ratePerHour: assessment.ratePerHour,
            delta1h: assessment.delta1h,
            delta3h: assessment.delta3h,
            delta6h: assessment.delta6h,
            escalatedByCorroboration: assessment.escalatedByCorroboration,
            corroborators: assessment.corroborators,
            tornadoStatus: tornadoStatusLabel,
            tornadoDrop10m: viewModel.tornadoSignature.drop10m,
            tornadoVolatility: viewModel.tornadoSignature.volatility,
            tornadoUnstable: viewModel.tornadoSignature.isAtmosphereUnstable,
            tornadoCorroborators: viewModel.tornadoSignature.corroborators,
            tornadoEscalated: viewModel.tornadoSignature.escalatedByCorroboration,
            temperature: viewModel.weather?.temperature,
            apparentTemperature: viewModel.weather?.apparentTemperature,
            humidity: viewModel.weather?.humidity,
            windSpeed: viewModel.weather?.windSpeed,
            windGust: viewModel.weather?.windGust,
            windDirection: viewModel.weather?.windDirection,
            dewPoint: viewModel.weather?.dewPoint,
            visibility: viewModel.weather?.visibility,
            cloudCover: viewModel.weather?.cloudCover,
            weatherDescription: viewModel.weather.map { WeatherCode.description($0.weatherCode) },
            precipitationNow: viewModel.weather?.precipitationNow,
            precipitationLast24h: viewModel.weather?.precipitationLast24h,
            cape: viewModel.weather?.cape,
            liftedIndex: viewModel.weather?.liftedIndex,
            alertCount: viewModel.alerts.count,
            hasTornadoWarning: viewModel.hasTornadoWarning,
            hasTornadoWatch: viewModel.hasTornadoWatch,
            alertHeadlines: viewModel.alerts.map { $0.properties.headline ?? $0.properties.event },
            outlookText: viewModel.outlooks.first { $0.day == 1 }.map { "\($0.categoryTitle) — tornado \($0.tornadoProbability ?? 0)%" },
            strikeCount: viewModel.magnetometer.strikeCount,
            lastStrikeKm: viewModel.magnetometer.estimatedDistanceKm,
            proximityLabel: viewModel.magnetometer.proximityLabel.rawValue,
            lightningEnabled: viewModel.settings.lightningDetectionEnabled,
            hasMagnetometer: DeviceCapability.hasMagnetometer,
            stationCount: viewModel.stations.count,
            stationAgreementVerdict: stationAgreementVerdict,
            stationMaxDelta: viewModel.stationAgreement?.maxAbsDelta,
            pressureGradientLabel: viewModel.pressureGradient?.compassLabel,
            pressureGradientMagnitude: viewModel.pressureGradient?.magnitudeHPaPer100km,
            confirmationVerdict: viewModel.confirmation?.title,
            confirmationDetail: viewModel.confirmation?.detail,
            rainbowVerdict: rainbowVerdictText,
            rainbowLook: viewModel.rainbowForecast?.lookInstruction,
            rainbowWrap: viewModel.rainbowForecast?.isWrapIndicatorActive ?? false,
            radarOffline: !(viewModel.radarStatus?.isOnline ?? true),
            radarSiteID: viewModel.radarStatus?.id,
            usesImperial: viewModel.settings.unitSystem == .imperial
        ))
    }

    private var tornadoStatusLabel: String {
        switch viewModel.tornadoSignature.status {
        case .insufficientData: return "Insufficient Data"
        case .quiet: return "Quiet"
        case .elevated: return "Elevated"
        case .signature: return "Signature Detected"
        }
    }

    private var stationAgreementVerdict: String {
        guard let a = viewModel.stationAgreement else { return "No data" }
        if a.maxAbsDelta < 1.5 { return "VERIFIED" }
        if a.maxAbsDelta < 4 { return "DRIFTING" }
        return "DIVERGENT"
    }

    private var rainbowVerdictText: String? {
        guard let f = viewModel.rainbowForecast else { return nil }
        switch f.verdict {
        case .likely: return "Likely — look now!"
        case .possible: return "Possible — keep an eye out"
        case .sunTooHigh: return "Sun too high (geometric limit)"
        case .night: return "Nighttime"
        case .noRain: return "No rain nearby"
        case .sunObscured: return "Sun obscured by cloud cover"
        }
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
        .stormGlass(in: Capsule(), tint: sensorChipColor)
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

    // MARK: - Floating Action Bar

    /// Share / info / settings, floating above the content in a single glass
    /// capsule (navigation-layer glass only, per Apple guidance).
    private func handleShareTap() {
        guard store.isUnlocked else {
            isShowingPaywall = true
            return
        }
        let report = ShareReport(text: buildReportSnapshot())
        shareReport = report
        isShowingShareSheet = true
    }

    private var actionBar: some View {
        HStack(spacing: 22) {
            barIcon("square.and.arrow.up", accessibility: "Share weather report") {
                handleShareTap()
            }
            barIcon("info.circle", accessibility: "How it works") {
                isShowingInfo = true
            }
            barIcon("gearshape", accessibility: "Settings") {
                isShowingSettings = true
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
        .stormGlass(in: Capsule(), interactive: true)
    }

    private func barIcon(_ systemImage: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibility)
    }

    private var locationLabel: String {
        if let name = viewModel.location.placeName {
            if viewModel.location.isApproximate { return "\(name) (approximate)" }
            return viewModel.location.isFallback ? "\(name) (default)" : name
        }
        return "Locating…"
    }
}

/// Identifiable wrapper so the share sheet presents with its report text
/// already built, instead of racing a `String` state update.
struct ShareReport: Identifiable {
    let id = UUID()
    let text: String
}

/// A collapsible group of secondary dashboard cards with a compact header.
/// Expansion state is persisted through `AppSettings` so the layout survives
/// relaunches.
///
/// Animation notes (tuned for `LazyVStack`):
/// - Opacity-only transitions — `.move` transitions make lazy-stack neighbors
///   reflow mid-animation and read as glitchy.
/// - One keyed animation on the section root drives height + chevron together.
/// - Heavy cards (maps, charts) are not built until the expand animation
///   finishes; shimmering skeletons hold the height in the meantime, so view
///   construction never hitches the animation (WWDC lazy-stack guidance:
///   avoid changing layout while subviews appear).
private struct DashboardSection<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    var isLoading: Bool = false
    var skeletonCount: Int = 2
    var lastUpdated: Date?
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    /// How long heavy content waits before building — just past the expand
    /// animation so construction lands after the height settles.
    /// (Instance constants — static stored properties aren't allowed on
    /// generic types.)
    private let contentMountDelay: Duration = .milliseconds(320)
    private let expandAnimation: Animation = .snappy(duration: 0.3)

    @State private var isContentMounted = false
    @State private var mountTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerButton

            if isExpanded {
                expandedBody
                    .transition(.opacity)
                    .compositingGroup()
            }
        }
        .animation(expandAnimation, value: isExpanded)
        .onAppear {
            // Sections that launch expanded (or scroll back into view) mount
            // their content immediately — no skeleton re-flash.
            if isExpanded && !isContentMounted {
                isContentMounted = true
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                scheduleContentMount()
            } else {
                mountTask?.cancel()
                mountTask = nil
                isContentMounted = false
            }
        }
    }

    private var headerButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .kerning(1)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if let lastUpdated {
                    HStack(spacing: 3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .medium))
                        // Live-updating relative time ("2 min ago").
                        Text(lastUpdated, style: .relative)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                        Text("ago")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .accessibilityLabel("Updated \(lastUpdated.formatted(.relative(presentation: .named))) ago")
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isExpanded ? "Collapse" : "Expand") \(title)")
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var expandedBody: some View {
        if isLoading || !isContentMounted {
            VStack(spacing: 18) {
                ForEach(0..<max(1, skeletonCount), id: \.self) { index in
                    SkeletonCard(height: index == 0 ? 190 : 150, tint: tint)
                }
            }
        } else {
            VStack(spacing: 18) {
                content()
            }
        }
    }

    /// Delays building the real cards until the expand animation has settled,
    /// then crossfades from the skeletons.
    private func scheduleContentMount() {
        mountTask?.cancel()
        isContentMounted = false
        mountTask = Task {
            try? await Task.sleep(for: contentMountDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.22)) {
                isContentMounted = true
            }
        }
    }
}

#Preview {
    ContentView()
}
