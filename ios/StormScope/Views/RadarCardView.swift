import SwiftUI
import CoreLocation

/// Animated NWS radar card: base reflectivity tiles over a dark map, active
/// warning polygons, and a scrubber for the last ~50 minutes of frames.
struct RadarCardView: View {
    let latitude: Double?
    let longitude: Double?
    let alerts: [NWSAlertFeature]

    /// Frame 0 is the oldest (-50 min); the last frame is live.
    private static let frameSuffixes: [String] = [
        "-m50m", "-m45m", "-m40m", "-m35m", "-m30m",
        "-m25m", "-m20m", "-m15m", "-m10m", "-m05m", "",
    ]

    @State private var frameIndex: Double = Double(frameSuffixes.count - 1)
    @State private var isPlaying = false
    @State private var selectedAlert: NWSAlertFeature?
    @State private var isRadarLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let latitude, let longitude {
                map(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                scrubber
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.cyan)
                    Text("Waiting for a location fix to load radar…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(for: .milliseconds(650))
                let next = Int(frameIndex) + 1
                frameIndex = Double(next >= Self.frameSuffixes.count ? 0 : next)
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cloud.rain.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.cyan)
            Text("Live Radar")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(frameLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLiveFrame ? Theme.green : Theme.amber)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((isLiveFrame ? Theme.green : Theme.amber).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func map(center: CLLocationCoordinate2D) -> some View {
        Color(.black)
            .frame(height: 320)
            .overlay {
                ZStack(alignment: .top) {
                    RadarMapRepresentable(
                        center: center,
                        frameSuffix: Self.frameSuffixes[Int(frameIndex)],
                        alerts: alerts,
                        onSelectAlert: { alert in
                            selectedAlert = alert
                        },
                        onTilesLoading: { loading in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isRadarLoading = loading
                            }
                        }
                    )

                    // Subtle loading bar that pulses while new tiles fetch.
                    if isRadarLoading {
                        loadingIndicator
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .bottom) {
                if let selectedAlert {
                    warningCallout(selectedAlert)
                        .padding(10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedAlert?.id)
    }

    private func warningCallout(_ alert: NWSAlertFeature) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: alert.isTornadoRelated ? "tornado" : "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(alert.properties.event)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Button {
                    selectedAlert = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Dismiss warning details")
            }
            .foregroundStyle(alert.isTornadoWarning ? Theme.red : Theme.orange)

            if let headline = alert.properties.headline {
                Text(headline)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
            }
            if let instruction = alert.properties.instruction {
                Text(instruction)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }

    private var scrubber: some View {
        HStack(spacing: 12) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.cyan)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(isPlaying ? "Pause radar animation" : "Play radar animation")
            .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)

            Slider(
                value: $frameIndex,
                in: 0...Double(Self.frameSuffixes.count - 1),
                step: 1
            ) {
                Text("Radar frame")
            }
            .tint(Theme.cyan)
            .onChange(of: frameIndex) { _, _ in
                // Manual scrubbing pauses playback so the frame sticks.
                if isPlaying == false { return }
            }
        }
    }

    private var isLiveFrame: Bool {
        Int(frameIndex) == Self.frameSuffixes.count - 1
    }

    private var frameLabel: String {
        let minutesAgo = (Self.frameSuffixes.count - 1 - Int(frameIndex)) * 5
        return minutesAgo == 0 ? "LIVE" : "-\(minutesAgo) min"
    }

    private var loadingIndicator: some View {
        Rectangle()
            .fill(Theme.cyan.opacity(0.7))
            .frame(height: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mask(
                GeometryReader { geometry in
                    Rectangle()
                        .frame(width: geometry.size.width * 0.35)
                        .offset(x: isRadarLoading ? geometry.size.width : -geometry.size.width * 0.35)
                        .animation(
                            .linear(duration: 1.2).repeatForever(autoreverses: false),
                            value: isRadarLoading
                        )
                }
            )
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        RadarCardView(latitude: 35.4676, longitude: -97.5164, alerts: [])
            .padding()
    }
}
