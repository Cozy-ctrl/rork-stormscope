import SwiftUI
import MapKit

/// Which measurement the station map pins display.
nonisolated enum StationMapMetric: String, CaseIterable, Identifiable {
    case pressure
    case dewPoint

    var id: String { rawValue }

    var title: String {
        self == .pressure ? "Pressure" : "Dew Point"
    }
}

/// A hideable map showing NWS observation stations around the device location.
/// Station pins show measured pressure; tapping reveals wind, temperature, and
/// a pressure delta against the device barometer. This spatial view helps spot
/// pressure gradients and wind-convergence zones — both severe-weather precursors.
struct StationsMapCardView: View {
    let stations: [StationObservation]
    let deviceLatitude: Double?
    let deviceLongitude: Double?
    let devicePressure: Double?
    let pressureMode: PressureDisplayMode
    let isLoading: Bool
    let errorMessage: String?
    @Binding var isExpanded: Bool
    @State private var selectedStation: StationObservation?
    @State private var cameraPosition: MapCameraPosition
    @State private var metric: StationMapMetric = .pressure

    init(stations: [StationObservation],
         deviceLatitude: Double?,
         deviceLongitude: Double?,
         devicePressure: Double?,
         pressureMode: PressureDisplayMode,
         isLoading: Bool,
         errorMessage: String?,
         isExpanded: Binding<Bool>) {
        self.stations = stations
        self.deviceLatitude = deviceLatitude
        self.deviceLongitude = deviceLongitude
        self.devicePressure = devicePressure
        self.pressureMode = pressureMode
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self._isExpanded = isExpanded

        // Center on the device or the midpoint of all station coordinates.
        let center: CLLocationCoordinate2D
        if let lat = deviceLatitude, let lon = deviceLongitude {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else if let first = stations.first {
            center = first.coordinate
        } else {
            center = CLLocationCoordinate2D(latitude: 39.8, longitude: -98.5)
        }
        let region = MKCoordinateRegion(
            center: center,
            latitudinalMeters: 160_000,
            longitudinalMeters: 160_000
        )
        self._cameraPosition = State(initialValue: .region(region))
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isExpanded {
                if stations.isEmpty && isLoading {
                    loadingView
                } else if stations.isEmpty, let errorMessage {
                    errorView(errorMessage)
                } else {
                    metricPicker
                    mapView
                    insightFooter
                }
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isExpanded)
    }

    // MARK: - Pieces

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isExpanded.toggle()
            }
            // Fit all pins when expanding.
            if isExpanded {
                recenter()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                Text("Station Map")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !stations.isEmpty {
                    Text("\(stations.count) stations")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse station map" : "Expand station map")
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    private var metricPicker: some View {
        HStack(spacing: 6) {
            ForEach(StationMapMetric.allCases) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        metric = option
                    }
                } label: {
                    Text(option.title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(metric == option ? Theme.ink : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(metric == option ? Theme.cyan : Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Show \(option.title) on station pins")
            }
        }
        .sensoryFeedback(.selection, trigger: metric)
    }

    private var mapView: some View {
        // Use the Color+overlay pattern for the map container so it has a
        // definite frame while Map fills it. Clip AFTER the overlay so the
        // map itself is rounded.
        Color(.black)
            .frame(height: 260)
            .overlay {
                Map(position: $cameraPosition) {
                    // Delta-colored connection lines from the device to each
                    // reporting station (pressure mode only) — the line color
                    // shows how strongly that station disagrees with the
                    // device barometer, making the local gradient visible.
                    if metric == .pressure,
                       let lat = deviceLatitude, let lon = deviceLongitude,
                       devicePressure != nil {
                        let deviceCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        ForEach(stations.filter { $0.pressureHPa != nil }) { station in
                            MapPolyline(coordinates: [deviceCoordinate, station.coordinate])
                                .stroke(
                                    pinColor(station).opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
                                )
                        }
                    }

                    // Device location marker.
                    if let lat = deviceLatitude, let lon = deviceLongitude {
                        Marker("You", systemImage: "location.circle.fill", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(Theme.cyan)
                    }

                    // Station pins; tapping a pin toggles its detail callout.
                    ForEach(stations) { station in
                        Annotation(station.id, coordinate: station.coordinate, anchor: .bottom) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedStation = selectedStation?.id == station.id ? nil : station
                                }
                            } label: {
                                stationPin(station)
                            }
                            .buttonStyle(.plain)
                        }
                        .annotationTitles(.hidden)
                    }
                }
                .mapStyle(.imagery(elevation: .flat))
                .mapControlVisibility(.hidden)
                // Detail callout for the selected station, floating over the map
                // so it never blocks other pins until requested.
                .overlay(alignment: .top) {
                    if let selected = selectedStation,
                       let current = stations.first(where: { $0.id == selected.id }) {
                        stationAnnotation(current)
                            .padding(.top, 10)
                            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                    }
                }
                // Computed pressure-gradient compass: the arrow points toward
                // falling pressure — the direction systems approach from.
                .overlay(alignment: .bottomLeading) {
                    if metric == .pressure, let gradient = pressureGradient, gradient.isSignificant {
                        gradientBadge(gradient)
                            .padding(8)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .onChange(of: stations.map(\.id)) { _, _ in
                recenter()
                // Drop a stale selection if the station list changed.
                if let selected = selectedStation, !stations.contains(where: { $0.id == selected.id }) {
                    selectedStation = nil
                }
            }
            .onChange(of: deviceLatitude) { _, _ in
                recenter()
            }
    }

    /// Fits the camera around the device and all station coordinates.
    private func recenter() {
        var coordinates: [CLLocationCoordinate2D] = stations.map { $0.coordinate }
        if let lat = deviceLatitude, let lon = deviceLongitude {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        guard !coordinates.isEmpty else { return }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // Pad the span so pins never sit on the edge; enforce a minimum zoom.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.35),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.35)
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    /// The inverse-distance-weighted pressure-gradient vector across the
    /// device and reporting stations; nil when flat or data is missing.
    private var pressureGradient: PressureGradient? {
        guard let lat = deviceLatitude, let lon = deviceLongitude,
              let device = devicePressure else { return nil }
        return PressureGradient.compute(
            stations: stations,
            deviceLatitude: lat,
            deviceLongitude: lon,
            devicePressure: device
        )
    }

    /// A small floating compass showing which way pressure is falling.
    private func gradientBadge(_ gradient: PressureGradient) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.amber)
                .rotationEffect(.degrees(gradient.towardLowBearingDeg))
            VStack(alignment: .leading, spacing: 0) {
                Text("Falls \(gradient.compassLabel)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(format: "%.1f hPa/100 km", gradient.magnitudeHPaPer100km))
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityLabel("Pressure is falling toward the \(gradient.compassLabel)")
    }

    /// A colored pin showing the selected metric (or a dash if unavailable).
    private func stationPin(_ station: StationObservation) -> some View {
        let color = pinColor(station)
        let valueText: String? = {
            switch metric {
            case .pressure:
                return nil
            case .dewPoint:
                return station.dewPointC.map { String(format: "%.0f°", $0) }
            }
        }()

        return VStack(spacing: 1) {
            VStack(spacing: 0) {
                Text(station.id.hasPrefix("K") ? String(station.id.dropFirst()) : station.id)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                if let valueText {
                    Text(valueText)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(color, in: .rect(cornerRadius: 5))
            Image(systemName: "triangle.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .offset(y: -2)
        }
    }

    private func pinColor(_ station: StationObservation) -> Color {
        switch metric {
        case .pressure:
            guard let pressure = station.pressureHPa else { return Theme.textTertiary }
            if let device = devicePressure {
                let delta = abs(pressure - device)
                if delta < 1.5 { return Theme.green }
                if delta < 4 { return Theme.amber }
                return Theme.orange
            }
            return Theme.cyan
        case .dewPoint:
            // Moisture scale: dry air amber → humid storm fuel cyan/orange.
            guard let dewPoint = station.dewPointC else { return Theme.textTertiary }
            if dewPoint >= 21 { return Theme.red }
            if dewPoint >= 18 { return Theme.orange }
            if dewPoint >= 13 { return Theme.cyan }
            if dewPoint >= 8 { return Theme.green }
            return Theme.amber
        }
    }

    /// An expanded callout shown when a station pin is tapped.
    private func stationAnnotation(_ station: StationObservation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Text(station.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedStation = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close station details")
            }

            if let pressure = station.pressureHPa {
                HStack(spacing: 4) {
                    Text(pressureMode.labeled(pressure))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if let device = devicePressure {
                        let delta = device - pressure
                        Text(String(format: "%+.1f hPa you", delta))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(abs(delta) > 4 ? Theme.amber : Theme.textTertiary)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(Theme.cyan)
            } else {
                Text("No pressure data")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }

            HStack(spacing: 8) {
                if let temp = station.temperatureC {
                    labelRow("\(String(format: "%.0f", temp))°C", icon: "thermometer.medium")
                }
                if let dew = station.dewPointC {
                    labelRow("\(String(format: "%.0f", dew))° dew", icon: "drop.fill")
                }
                if let wind = station.windSpeedKmh {
                    let dir = station.windDirectionDeg.map(windArrow) ?? ""
                    labelRow("\(dir) \(String(format: "%.0f", wind)) km/h", icon: "wind")
                }
                if let hum = station.humidity {
                    labelRow("\(hum)%", icon: "humidity.fill")
                }
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 4) {
                Text(String(format: "%.1f km", station.distanceKm))
                if let obs = station.observedAt {
                    Text("• \(obs.formatted(.relative(presentation: .named)))")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(Theme.textTertiary)
        }
        .padding(10)
        .frame(width: 220)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .environment(\.colorScheme, .dark)
    }

    private func labelRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
        }
    }

    private var insightFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let insight = gradientInsight {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.amber)
                    Text(insight)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let dryline = drylineInsight {
                HStack(spacing: 6) {
                    Image(systemName: "drop.triangle")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.orange)
                    Text(dryline)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(footerHint)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerHint: String {
        switch metric {
        case .pressure:
            return "Tap a station pin for details. Pin and line colors show pressure agreement with your sensor — green is close, orange means a gradient is present. The compass badge points toward falling pressure, where systems usually arrive from."
        case .dewPoint:
            return "Pin color shows moisture — amber is dry air, cyan/orange is humid storm fuel. A sharp dry-to-moist boundary between nearby stations is a dryline, where storms often initiate."
        }
    }

    /// Detects a large dew point contrast across nearby stations — the
    /// classic dryline signature where storms fire. Returns nil when calm.
    private var drylineInsight: String? {
        let dewPoints = stations.compactMap { $0.dewPointC }
        guard dewPoints.count >= 2,
              let minD = dewPoints.min(), let maxD = dewPoints.max() else { return nil }
        let spread = maxD - minD
        if spread >= 8 {
            return String(format: "Dryline signature: %.0f°C dew point contrast across nearby stations — storm initiation possible along the moisture boundary.", spread)
        } else if spread >= 5 {
            return String(format: "Notable dew point gradient (%.0f°C spread) — a moisture boundary is nearby.", spread)
        }
        return nil
    }

    /// Detects notable pressure gradients across stations — a classic
    /// approaching-front signature. Returns nil when nothing notable.
    private var gradientInsight: String? {
        let withPressure = stations.filter { $0.pressureHPa != nil }
        guard withPressure.count >= 2 else { return nil }
        let pressures = withPressure.compactMap { $0.pressureHPa }
        guard let minP = pressures.min(), let maxP = pressures.max() else { return nil }
        let spread = maxP - minP
        if spread > 6 {
            return "Strong pressure gradient detected (\(String(format: "%.1f", spread)) hPa spread across stations) — possible approaching front or low-pressure system."
        } else if spread > 3 {
            return "Moderate pressure gradient (\(String(format: "%.1f", spread)) hPa spread) — watch for wind shifts."
        }
        return nil
    }

    // MARK: - Placeholders

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Theme.cyan)
            Text("Loading station positions…")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(Theme.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    /// Wind direction in degrees to a short arrow label.
    private func windArrow(_ degrees: Double) -> String {
        switch degrees {
        case 0..<22.5, 337.5...: return "N"
        case 22.5..<67.5:       return "NE"
        case 67.5..<112.5:      return "E"
        case 112.5..<157.5:     return "SE"
        case 157.5..<202.5:     return "S"
        case 202.5..<247.5:     return "SW"
        case 247.5..<292.5:     return "W"
        case 292.5..<337.5:     return "NW"
        default:                return ""
        }
    }
}

// MARK: - Hashable & Equatable conformance for Map selection binding
extension StationObservation: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    public static func == (lhs: StationObservation, rhs: StationObservation) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        StationsMapCardView(
            stations: [
                StationObservation(
                    id: "KSFO", name: "San Francisco Intl Airport",
                    latitude: 37.619, longitude: -122.375, distanceKm: 5.2,
                    pressureHPa: 1013.2, temperatureC: 18.5, dewPointC: 12.1,
                    windSpeedKmh: 22, windGustKmh: nil, windDirectionDeg: 280,
                    humidity: 67, visibilityM: 16000, precipLastHourMm: nil,
                    conditions: "Partly Cloudy", observedAt: Date()
                ),
                StationObservation(
                    id: "KOAK", name: "Oakland Metro Airport",
                    latitude: 37.721, longitude: -122.221, distanceKm: 18.7,
                    pressureHPa: 1009.1, temperatureC: 17.2, dewPointC: 13.5,
                    windSpeedKmh: 15, windGustKmh: nil, windDirectionDeg: 250,
                    humidity: 78, visibilityM: 12000, precipLastHourMm: 0.2,
                    conditions: "Mostly Cloudy", observedAt: Date()
                ),
                StationObservation(
                    id: "KNUQ", name: "Moffett Federal Airfield",
                    latitude: 37.416, longitude: -122.049, distanceKm: 28.3,
                    pressureHPa: 1015.8, temperatureC: 20.1, dewPointC: 10.8,
                    windSpeedKmh: 10, windGustKmh: nil, windDirectionDeg: 310,
                    humidity: 55, visibilityM: 16000, precipLastHourMm: nil,
                    conditions: "Clear", observedAt: Date()
                ),
            ],
            deviceLatitude: 37.52,
            deviceLongitude: -122.25,
            devicePressure: 1012.5,
            pressureMode: .hPa,
            isLoading: false,
            errorMessage: nil,
            isExpanded: .constant(true)
        )
        .padding()
    }
}
