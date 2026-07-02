import SwiftUI

/// Explains how barometric storm detection works and the thresholds used.
struct InfoSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Your iPhone has a barometer accurate to a fraction of a hectopascal. Because it measures the air around *you* — not a station kilometers away — it can flag an incoming pressure front minutes to hours before regional reports update.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Pressure Tendency Guide")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    VStack(spacing: 10) {
                        thresholdRow(level: .rising, range: "Rising ≥ +0.8 hPa/h")
                        thresholdRow(level: .steady, range: "Within ±0.6 hPa/h")
                        thresholdRow(level: .falling, range: "Falling 0.6 – 1.5 hPa/h")
                        thresholdRow(level: .stormLikely, range: "Falling 1.5 – 3 hPa/h")
                        thresholdRow(level: .frontImminent, range: "Falling > 3 hPa/h")
                    }

                    Text("Tips")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Alerts & Intelligence")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: 10) {
                        tipRow(icon: "antenna.radiowaves.left.and.right", text: "Official National Weather Service alerts (api.weather.gov) are pulled for your exact GPS point — the same feed stations relay, with no middleman. U.S. coverage only.")
                        tipRow(icon: "sensor.tag.radiowaves.forward", text: "The Nearest NWS Stations card pulls real measured readings from the closest official observation stations, so you can compare your sensor against actual instruments nearby.")
                        tipRow(icon: "tornado", text: "Tornado Signature Mode watches a tight 10-minute window for abrupt, rotation-scale pressure drops and fuses them with NWS tornado watches and warnings.")
                        tipRow(icon: "apple.intelligence", text: "On iOS 26 devices with Apple Intelligence, the on-device model turns live sensor data into plain-language feedback — entirely offline, nothing leaves your iPhone.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        tipRow(icon: "clock", text: "Keep the app open ~15 minutes for the first trend estimate; accuracy improves with hours of data.")
                        tipRow(icon: "figure.stairs", text: "Elevation changes (stairs, elevators, driving uphill) shift readings — trends are most reliable when you stay at one altitude.")
                        tipRow(icon: "building.columns", text: "The station comparison shows how your hyper-local reading differs from the regional weather model.")
                        tipRow(icon: "exclamationmark.triangle", text: "This is an early-warning aid, not a replacement for official severe weather alerts.")
                    }
                }
                .padding(20)
            }
            .background(Theme.ink)
            .navigationTitle("How It Works")
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
    }

    private func thresholdRow(level: StormLevel, range: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: level.systemImage)
                .font(.system(size: 18))
                .foregroundStyle(level.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(level.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(range)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 14))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.amber)
                .frame(width: 22)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    InfoSheetView()
}
