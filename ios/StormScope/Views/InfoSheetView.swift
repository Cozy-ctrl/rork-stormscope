import SwiftUI

/// Comprehensive guide to every sensor, data source, metric, and threshold
/// StormScope uses. Structured as a scrollable reference the user can revisit
/// anytime from the dashboard info button.
struct InfoSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro
                    barometerSection
                    mslpSection
                    magnetometerSection
                    atmosphericSection
                    tornadoSection
                    alertsSection
                    mapSection
                    outlookSection
                    stationsSection
                    aiSection
                    ipSection
                    tipsSection
                    disclaimerBlock
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

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("StormScope turns your iPhone into a personal weather station, fusing on-device sensors with official data sources to give you early awareness of approaching severe weather.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Each section below explains a system in detail — what it measures, how the thresholds work, and where the data comes from.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Barometer

    private var barometerSection: some View {
        section(
            icon: "gauge.with.dots.needle.50percent",
            title: "Barometric Pressure",
            tint: Theme.cyan
        ) {
            Text("Your iPhone has a barometer accurate to a fraction of a hectopascal. Because it measures the air around *you* — not a station kilometers away — it can flag an incoming pressure front minutes to hours before regional reports update.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Pressure Tendency Thresholds")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            VStack(spacing: 6) {
                threshold(level: .rising, detail: "Rising \u{2265} +0.8 hPa/h")
                threshold(level: .steady, detail: "Within \u{00B1}0.6 hPa/h")
                threshold(level: .falling, detail: "Falling 0.6\u{20131}.5 hPa/h")
                threshold(level: .stormLikely, detail: "Falling 1.5\u{20133}.0 hPa/h")
                threshold(level: .frontImminent, detail: "Falling >3.0 hPa/h")
            }

            Text("Trends use a least-squares regression over the last 60 minutes and require at least 15 minutes of data. A large sustained 3-hour drop can also escalate the level even if the last hour has momentarily flattened.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    // MARK: - MSLP

    private var mslpSection: some View {
        section(
            icon: "globe.americas.fill",
            title: "Mean Sea Level Pressure (MSLP)",
            tint: Theme.green
        ) {
            Text("Raw barometer readings drop ~1.2 hPa for every 100 metres of elevation — two phones at different altitudes will show different numbers even in the same weather system. MSLP uses your GPS altitude and the current surface temperature to correct the reading to sea level, making it directly comparable to official NWS station reports.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Toggle MSLP in Settings \u{2192} Measurement Units. When enabled, the pressure-display label shows \u{201C}(MSLP)\u{201D} so you always know which reference plane is in use. Trend analysis always uses raw station pressure regardless — the multiplicative MSLP correction preserves relative changes.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Magnetometer

    private var magnetometerSection: some View {
        section(
            icon: "bolt.fill",
            title: "Lightning Detection (Magnetometer)",
            tint: Theme.amber
        ) {
            Text("Lightning strikes emit an electromagnetic pulse (EMP) that the iPhone magnetometer can sense. The detector watches for sudden spikes in the total magnetic field and applies five layers of false-positive suppression:")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("8 \u{00B5}T threshold \u{2014} phone movement alone produces 10\u{20135}0 \u{00B5}T; anything below 8 \u{00B5}T is ignored.")
                bullet("Transient-spike verification \u{2014} real EMP spikes and decays in under a second. Sustained elevation means device movement.")
                bullet("Stability gate \u{2014} detection pauses when the phone is being handled (high magnetic variance) and re-arms after 2 seconds of stillness.")
                bullet("Minimum 3-second interval between distinct strikes.")
                bullet("Rolling rate cap of 10 events per minute.")
            }

            Text("Distance Estimation")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            Text("A strong cloud-to-ground strike produces roughly 30 \u{00B5}T\u{00B7}km \u{2014} about 30 \u{00B5}T at 1 km, falling to ~3 \u{00B5}T at 10 km. With an 8 \u{00B5}T detection floor, only close-range strikes (within ~4 km) are registered. Distance buckets are approximate and vary with strike current and device orientation.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                proximityRow(label: "Very Close", range: "<1 km", color: Theme.red)
                proximityRow(label: "Nearby", range: "1\u{20132} km", color: Theme.orange)
                proximityRow(label: "Distant", range: "2\u{20134} km", color: Theme.amber)
                proximityRow(label: "Far", range: ">4 km", color: Theme.green)
            }
            .padding(.top, 2)

            Text("Detections age out after one hour and the proximity label resets to \u{201C}Listening\u{201D} after 10 minutes with no new strikes. Lightning detection can be turned off in Settings \u{2192} Alerts & Monitoring to save battery.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Atmospheric instability

    private var atmosphericSection: some View {
        section(
            icon: "chart.xyaxis.line",
            title: "Atmospheric Instability (CAPE & Lifted Index)",
            tint: Theme.orange
        ) {
            Text("CAPE (Convective Available Potential Energy, in J/kg) and Lifted Index (in \u{00B0C}) are standard meteorology metrics pulled from the Open-Meteo weather model. They measure how much \u{201Cf}uel\u{201D} the atmosphere has for thunderstorm development.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("CAPE Tiers")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                bullet("0\u{20131}000: Stable to marginally unstable.")
                bullet("1000\u{20132}500: Moderately unstable \u{2014} storms possible.")
                bullet("2500\u{20134}000: Very unstable \u{2014} severe storms possible.")
                bullet(">4000: Extremely unstable \u{2014} explosive development.")
            }

            Text("Lifted Index Tiers")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                bullet(">0: Stable.")
                bullet("0 to \u{22122}: Marginal \u{2014} isolated storms.")
                bullet("\u{22122} to \u{22124}: Unstable \u{2014} scattered storms.")
                bullet("\u{22124} to \u{22126}: Very unstable \u{2014} widespread severe.")
                bullet("<\u{22126}: Extremely unstable \u{2014} explosive.")
            }

            Text("When CAPE \u{2265} 2500 J/kg or Lifted Index \u{2264} \u{22124}, the tornado signature analysis tightens its pressure-drop thresholds because the environment can support severe rotation with weaker pressure signals.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tornado

    private var tornadoSection: some View {
        section(
            icon: "tornado",
            title: "Tornado Signature Analysis",
            tint: Theme.red
        ) {
            Text("Tornadic mesocyclones produce abrupt, rotation-scale pressure falls over minutes \u{2014} much faster than a synoptic front\u{2019}s hours-long decline. The signature analyzer watches a tight 10-minute window and measures sample-to-sample volatility over 30 minutes.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("Signature: 10-minute drop \u{2264} \u{22121}.2 hPa, OR \u{2264} \u{22120}.8 hPa with an unstable atmosphere (high CAPE / strongly negative Lifted Index).")
                bullet("Elevated: 10-minute drop \u{2264} \u{22120}.5 hPa, OR \u{2264} \u{22120}.3 hPa with an unstable atmosphere, OR sustained minute-to-minute jitter \u{2265} 0.15 hPa.")
                bullet("Quiet: No rotation-scale pressure behavior detected.")
                bullet("Insufficient data: Fewer than 4 samples in the 10-minute window or less than 5 minutes of data.")
            }

            Text("A single barometer cannot confirm a tornado \u{2014} the signature is one data point, always paired with official NWS tornado watches and warnings for life-safety decisions.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        section(
            icon: "exclamationmark.triangle.fill",
            title: "NWS Alerts",
            tint: Theme.red
        ) {
            Text("Official National Weather Service alerts are pulled from api.weather.gov for your exact GPS coordinates \u{2014} the same feed that weather radios and local stations relay. Coverage is U.S. only.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tornado warnings trigger a time-sensitive critical notification when enabled in Settings. Storm notifications fire when the barometer\u{2019}s pressure trend reaches Storm Watch or Front Imminent. Both notification types respect your iOS notification settings and can be turned off independently.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        section(
            icon: "map.fill",
            title: "Radar & Satellite Map",
            tint: Theme.cyan
        ) {
            Text("The radar card shows live NEXRAD composite reflectivity tiles from the Iowa Environmental Mesonet. A layer toggle lets you switch between Radar, Satellite, or Both.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Satellite mode streams GOES-East infrared imagery \u{2014} colder (brighter) cloud tops indicate higher, more intense storm clouds. \u{201CB}oth\u{201D} stacks the satellite underneath the radar sweep so you can see storm structure and precipitation together. The app also checks whether the nearest NEXRAD radar site is actively reporting; if it is down for maintenance a small notice appears on the card.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Radar and satellite are delayed by several minutes and should not be used for minute-by-minute storm tracking.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Outlook

    private var outlookSection: some View {
        section(
            icon: "rectangle.3.group.fill",
            title: "SPC Convective Outlooks",
            tint: Theme.amber
        ) {
            Text("The Storm Prediction Center issues daily categorical outlooks for severe weather risk. StormScope pulls Day 1, 2, and 3 outlooks from the Iowa Environmental Mesonet.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                bullet("Marginal (MRGL): Isolated severe storms possible.")
                bullet("Slight (SLGT): Scattered severe storms possible.")
                bullet("Enhanced (ENH): Numerous severe storms possible.")
                bullet("Moderate (MDT): Widespread severe storms likely.")
                bullet("High (HIGH): A severe weather outbreak is expected.")
            }

            Text("Each outlook includes categorical tornado, wind, and hail probabilities as percentages. The AI insight card incorporates the Day 1 outlook category when summarising your situation.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Stations

    private var stationsSection: some View {
        section(
            icon: "antenna.radiowaves.left.and.right",
            title: "Nearby NWS Stations & Calibration",
            tint: Theme.green
        ) {
            Text("The app discovers the closest official NWS observation stations and pulls their latest reported readings — temperature, wind, dew point, visibility, and sea-level-corrected barometric pressure. This lets you compare your on-device sensor against real instruments nearby.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("One-tap calibration in Settings aligns your device barometer to the nearest reporting station, zeroing out factory variance between devices. The calibration offset is additive and does not affect trend analysis (a constant offset cancels out in change calculations). When MSLP is enabled, both the device and the station report on the same sea-level plane, so the offset reflects only sensor drift \u{2014} typically less than 0.5 hPa.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - AI

    private var aiSection: some View {
        section(
            icon: "apple.intelligence",
            title: "On-Device AI Insight",
            tint: Theme.cyan
        ) {
            Text("On iOS 26 devices with Apple Intelligence, the on-device Foundation Model reads your live sensor data and produces a plain-language briefing. It receives current pressure, trend, tornado signature status, active NWS alerts, weather conditions, CAPE, Lifted Index, lightning strike counts, and the SPC Day 1 outlook.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything runs on-device \u{2014} no data leaves your iPhone. The insight is probabilistic guidance, not a forecast. On devices without Apple Intelligence, the card shows the standard level description instead.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - IP fallback

    private var ipSection: some View {
        section(
            icon: "wifi",
            title: "Location Fallback",
            tint: Theme.textSecondary
        ) {
            Text("If you deny GPS access, StormScope looks up your approximate city from your network connection (no permission or account needed). This gives you a rough location for alerts, radar centering, and weather data instead of defaulting to a fixed city.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("When using network-based location, a subtle banner appears on the dashboard. Enable Location access in iOS Settings for precise, real-time positioning and full barometer altitude correction.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        section(
            icon: "lightbulb.fill",
            title: "Tips for Reliable Readings",
            tint: Theme.amber
        ) {
            VStack(alignment: .leading, spacing: 8) {
                tip("clock", "Keep the app open for ~15 minutes for the first trend estimate; accuracy improves with hours of continuous data.")
                tip("figure.stairs", "Elevation changes (stairs, elevators, driving uphill) shift readings \u{2014} pressure trends are most reliable when you stay at one altitude. Enable MSLP to compensate automatically.")
                tip("hand.raised.fill", "For lightning detection, keep the phone stationary on a flat surface. Movement or nearby electronics (chargers, speakers) create false strikes.")
                tip("moon.zzz.fill", "Background Monitoring in Settings keeps the barometer sampling while the app is closed using significant-location-change wakeups. Battery impact is minimal.")
                tip("bolt.badge.clock", "The Lock Screen Live Activity shows your current pressure and trend without opening the app \u{2014} enable it in Settings.")
                tip("exclamationmark.shield.fill", "This is an early-warning aid, not a replacement for official severe weather alerts. Always follow instructions from NOAA Weather Radio, local NWS alerts, and civil authorities for life-safety decisions.")
            }
        }
    }

    // MARK: - Disclaimer footer

    private var disclaimerBlock: some View {
        VStack(spacing: 6) {
            Text("StormScope is an early-warning aid, not a replacement for official severe weather alerts. Barometric and magnetometer data is collected from a single point and cannot confirm specific hazard types on its own. Always rely on NOAA Weather Radio, local NWS alerts, and civil authority instructions for life-safety decisions.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func section<Content: View>(
        icon: String,
        title: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
            }
            content()
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.panelStroke, lineWidth: 1)
        )
    }

    private func threshold(level: StormLevel, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: level.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(level.tint)
                .frame(width: 24)
            Text(level.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 3)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\u{2022}")
                .foregroundStyle(Theme.textTertiary)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func proximityRow(label: String, range: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 80, alignment: .leading)
            Text(range)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .padding(.vertical, 1)
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.amber)
                .frame(width: 20)
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
