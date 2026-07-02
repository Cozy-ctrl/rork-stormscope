import SwiftUI

/// Comprehensive guide to every sensor, data source, metric, and threshold
/// StormScope uses. Structured as a scrollable reference organised by category
/// so the user can revisit any topic anytime from the dashboard info button.
struct InfoSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    intro

                    // MARK: Core Instrument
                    stormLevelsSection
                    gaugeModesSection
                    tendencySection
                    trendChartSection
                    barometerSection
                    mslpSection

                    // MARK: On-Device Sensors
                    magnetometerSection

                    // MARK: Atmospheric Analysis
                    atmosphericSection
                    tornadoSection
                    rainbowSection

                    // MARK: Official Data Sources
                    alertsSection
                    mapSection
                    velocityRadarSection
                    outlookSection

                    // MARK: Station Verification
                    stationsSection
                    stationsMapSection
                    stationObservedSection
                    deviceDeltaSection

                    // MARK: Intelligence Layer
                    eventConfirmationSection
                    aiSection

                    // MARK: Background & Extras
                    backgroundSection
                    widgetSection
                    demoSection
                    ipSection

                    // MARK: Reference
                    settingsOverviewSection
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

    // MARK: - Storm Levels & Banner

    private var stormLevelsSection: some View {
        section(
            icon: "cloud.bolt.fill",
            title: "Storm Levels & Status Banner",
            tint: Theme.orange
        ) {
            Text("The large banner at the top of the dashboard is your single-glance summary. It shows one of six storm levels — from Calibrating through Front Imminent — derived from your barometer's pressure trend. Each level has its own icon, colour, and detailed description.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Levels (least to most severe)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            VStack(spacing: 6) {
                threshold(level: .collecting, detail: "Gathering samples — needs ~15 min")
                threshold(level: .rising, detail: "Rising \u{2265} +0.8 hPa/h")
                threshold(level: .steady, detail: "Within \u{00B1}0.6 hPa/h")
                threshold(level: .falling, detail: "Falling 0.6\u{20131}.5 hPa/h")
                threshold(level: .stormLikely, detail: "Falling 1.5\u{20133}.0 hPa/h")
                threshold(level: .frontImminent, detail: "Falling >3.0 hPa/h")
            }

            Text("At Storm Watch and above, the banner pulses gently and the border glows. At Front Imminent, the app delivers haptic feedback. The banner updates in real time as new barometer readings arrive (roughly once per second).")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Gauge Display Modes

    private var gaugeModesSection: some View {
        section(
            icon: "gauge.with.dots.needle.50percent",
            title: "Pressure Gauge & Display Modes",
            tint: Theme.cyan
        ) {
            Text("The large circular gauge is the centrepiece of the dashboard. It shows your current barometric pressure in real time, with the needle position reflecting the trend direction. You can choose from four display modes in Settings:")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("hPa — hectopascals, the international meteorological standard. Shows one decimal place.")
                bullet("inHg — inches of mercury, the U.S. standard. Shows two decimal places.")
                bullet("mmHg — millimetres of mercury, common in medical and legacy contexts.")
                bullet("Dual (hPa + inHg) — shows both values side by side at equal weight, each with its own unit label. The MSLP badge and calibration checkmark sit centred above both.")
            }

            Text("When MSLP is enabled in Settings, a small \u{201C}MSLP\u{201D} badge appears next to the reading, confirming the value has been adjusted to sea level. A green checkmark badge appears when your barometer is calibrated to a nearby NWS station.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 1h / 3h / 6h Tendency Cards

    private var tendencySection: some View {
        section(
            icon: "arrow.up.and.down.circle",
            title: "1h / 3h / 6h Tendency Cards",
            tint: Theme.green
        ) {
            Text("Three compact cards sit directly below the gauge, showing short-, medium-, and long-term pressure change. Each card displays a directional arrow and the signed delta in your chosen pressure unit.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("1h — the last hour's net change. Useful for spotting rapid development.")
                bullet("3h — the classic meteorology standard for pressure-tendency reports.")
                bullet("6h — reveals whether a trend is sustained or transient.")
            }

            Text("Arrows are colour-coded: green for steady, cyan for rising, amber/orange for moderate drop, red for severe drop (\u{2264} \u{22123} hPa). Cards show an hourglass placeholder when insufficient data is available. Text auto-scales so large deltas never overflow the card.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Interactive Trend Chart

    private var trendChartSection: some View {
        section(
            icon: "chart.xyaxis.line",
            title: "Interactive Trend Chart",
            tint: Theme.cyan
        ) {
            Text("A scrollable area chart plots your pressure over the last 6 hours. The smoothed line (Catmull-Rom interpolation) makes the trend direction immediately obvious, while the gradient fill gives a sense of magnitude.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The chart has its own independent hPa / inHg toggle in the header, separate from the gauge. This lets meteorologists keep the chart in hPa (the global analysis standard) even when their spot readout is in inHg. Hourly axis labels and trailing-grid marks frame the data without clutter.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The Y-axis auto-scales with 20% padding so even subtle trends are visible. When fewer than 2 readings exist, a placeholder appears instead of an empty chart. The chart is purely visual — it does not support pinch-to-zoom or point selection.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Barometer (Trend Detection)

    private var barometerSection: some View {
        section(
            icon: "sensor",
            title: "Barometric Pressure & Trend Detection",
            tint: Theme.cyan
        ) {
            Text("Your iPhone has a barometer accurate to a fraction of a hectopascal. Because it measures the air around *you* — not a station kilometres away — it can flag an incoming pressure front minutes to hours before regional reports update.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Trends use a least-squares regression over the last 60 minutes and require at least 15 minutes of data. A large sustained 3-hour drop can also escalate the level even if the last hour has momentarily flattened. Minute-to-minute volatility (jitter) is tracked separately and feeds the tornado signature analyser.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The barometer is sampled roughly once per second when the app is active. In the background, sampling continues using significant-location-change wakeups — see the Background Monitoring section below.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
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
                bullet("12 \u{00B5}T threshold \u{2014} phone movement alone produces 10\u{20135}0 \u{00B5}T; anything below 12 \u{00B5}T is ignored to eliminate false readings.")
                bullet("Transient-spike verification \u{2014} real EMP spikes and decays in under a second. Sustained elevation means device movement.")
                bullet("Stability gate \u{2014} detection pauses when the phone is being handled (high magnetic variance) and re-arms after 2 seconds of stillness.")
                bullet("Minimum 3-second interval between distinct strikes.")
                bullet("Rolling rate cap of 10 events per minute.")
            }

            Text("Distance Estimation")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            Text("A strong cloud-to-ground strike produces roughly 30 \u{00B5}T\u{00B7}km \u{2014} about 30 \u{00B5}T at 1 km, falling to ~3 \u{00B5}T at 10 km. With a 12 \u{00B5}T detection floor, only very close strikes (within ~2.5 km) are registered. Distance buckets are approximate and vary with strike current and device orientation.")
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
            Text("CAPE (Convective Available Potential Energy, in J/kg) and Lifted Index (in \u{00B0}C) are standard meteorology metrics pulled from the Open-Meteo weather model. They measure how much \u{201C}fuel\u{201D} the atmosphere has for thunderstorm development. Both values appear in the Local Conditions grid with colour-coded severity labels.")
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
            Text("Tornadic mesocyclones produce abrupt, rotation-scale pressure falls over minutes \u{2014} much faster than a synoptic front\u{2019}s hours-long decline. The signature analyser watches a tight 10-minute window and measures sample-to-sample volatility over 30 minutes.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("Signature: 10-minute drop \u{2264} \u{22121}.2 hPa, OR \u{2264} \u{22120}.8 hPa with an unstable atmosphere (high CAPE / strongly negative Lifted Index).")
                bullet("Elevated: 10-minute drop \u{2264} \u{22120}.5 hPa, OR \u{2264} \u{22120}.3 hPa with an unstable atmosphere, OR sustained minute-to-minute jitter \u{2265} 0.15 hPa.")
                bullet("Quiet: No rotation-scale pressure behaviour detected.")
                bullet("Insufficient data: Fewer than 4 samples in the 10-minute window or less than 5 minutes of data.")
            }

            Text("A single barometer cannot confirm a tornado \u{2014} the signature is one data point, always paired with official NWS tornado watches and warnings for life-safety decisions.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Rainbow Watch

    private var rainbowSection: some View {
        section(
            icon: "rainbow",
            title: "Rainbow Watch & Wrap Indicator",
            tint: Theme.cyan
        ) {
            Text("Rainbows appear at exactly 42\u{00B0} from the anti-solar point \u{2014} directly opposite the sun. This is pure geometry: when the sun climbs above 42\u{00B0} elevation, no rainbow is visible from the ground, period. StormScope computes the sun\u{2019}s exact position from your GPS location and the time, then cross-checks live rain (weather model rate, nearby station rain gauges, current conditions code) and cloud cover.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("Likely \u{2014} sun below 42\u{00B0}, rain falling, cloud cover under 75%. The card shows the exact compass bearing to look and how high the bow\u{2019}s top arc sits above the horizon (42\u{00B0} minus sun elevation).")
                bullet("Possible \u{2014} geometry works but conditions are marginal: heavy cloud that needs a sunlight gap, or rain close by rather than overhead.")
                bullet("Hidden \u{2014} the card stays off the dashboard at night, when the sun is too high, when no rain is near, or under solid overcast.")
            }

            Text("Rainbow Wrap \u{2014} chaser indicator")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            Text("\u{201C}Rainbow wrap\u{201D} is a bow forming inside the rain curtain wrapping around a supercell\u{2019}s updraft \u{2014} storm chasers recognise it as a sign of organised severe rotation, sometimes visible around tornadogenesis. When the tornado signature analyser reports Elevated or Signature while rainbow optics are simultaneously possible, the card adds a red wrap-check note and the AI briefing is informed.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The wrap check is a secondary, experimental indicator \u{2014} it never changes the optical verdict or storm level, and it is no substitute for official NWS warnings. All calculations run on-device with no extra network requests.")
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
            Text("Official National Weather Service alerts are pulled from api.weather.gov for your exact GPS coordinates \u{2014} the same feed that weather radios and local stations relay. Coverage is U.S. only. Active alerts appear as red/amber strips below the storm banner.")
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
            Text("The radar card shows live NEXRAD composite reflectivity tiles from the Iowa Environmental Mesonet. A layer toggle lets you switch between Radar, Satellite, Velocity, or stacked combinations.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Satellite mode streams GOES-East infrared imagery \u{2014} colder (brighter) cloud tops indicate higher, more intense storm clouds. \u{201C}Both\u{201D} stacks the satellite underneath the radar sweep so you can see storm structure and precipitation together. Velocity (see next section) adds wind-field detail. The app also checks whether the nearest NEXRAD radar site is actively reporting; if it is down for maintenance a small notice appears on the card.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Radar, satellite, and velocity are delayed by 5\u{2013}15 minutes and should not be used for minute-by-minute storm tracking.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Velocity radar

    private var velocityRadarSection: some View {
        section(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "Velocity Radar",
            tint: Theme.cyan
        ) {
            Text("In addition to reflectivity radar, the map layer toggle offers a Storm Relative Velocity product from the nearest NEXRAD site. Green pixels indicate motion toward the radar; red pixels indicate motion away. A tight green/red couplet side by side — the classic velocity signature of rotation — can reveal a developing mesocyclone before reflectivity shows a hook echo.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Velocity data comes from single-site RIDGE tiles (Iowa Environmental Mesonet). The site is auto-selected as the nearest reporting NEXRAD to your location. Satellite and radar layers are independent — you can view any combination with the layered map controls.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Velocity imagery has the same 5\u{2013}15 minute delay as reflectivity and should not be used for minute-by-minute tornado confirmation. It is one additional data point alongside reflectivity, satellite, and surface observations.")
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
            Text("The Storm Prediction Center issues daily categorical outlooks for severe weather risk. StormScope pulls Day 1, 2, and 3 outlooks from the Iowa Environmental Mesonet. Tap the day switcher to see each forecast horizon.")
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
            Text("The app discovers the closest official NWS observation stations and pulls their latest reported readings — temperature, wind, dew point, visibility, and sea-level-corrected barometric pressure. This lets you compare your on-device sensor against real instruments nearby. The station list is collapsed by default; tap the header to reveal individual station cards.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("One-tap calibration in Settings aligns your device barometer to the nearest reporting station, zeroing out factory variance between devices. The calibration offset is additive and does not affect trend analysis (a constant offset cancels out in change calculations). When MSLP is enabled, both the device and the station report on the same sea-level plane, so the offset reflects only sensor drift \u{2014} typically less than 0.5 hPa. A green checkmark badge on the gauge confirms calibration is active.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Station map & comparison

    private var stationsMapSection: some View {
        section(
            icon: "map.fill",
            title: "Station Map & Comparison Charts",
            tint: Theme.cyan
        ) {
            Text("The Station Map places every NWS observation site around you on a satellite map. Pin colour shows pressure agreement with your device (green = close, orange/red = a gradient is present). Tapping a pin reveals that station\u{2019}s full observation in a floating detail card. When multiple stations are visible, connection lines trace the pressure gradient across the map \u{2014} coloured from green (agreement) to red (divergence) so you can see spatial pressure structure at a glance. Switch to the Dew Point view to see moisture distribution \u{2014} a sharp dry-to-moist boundary between nearby stations is a dryline, a classic storm-initiation trigger.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The Station Comparison chart lets you pick any measured quantity — pressure, temperature, dew point, wind speed, or humidity — and see it as interactive bars ordered by distance. Gradient callouts flag notable spreads between stations that may signal fronts, outflow boundaries, or drylines. Tapping a bar highlights that station\u{2019}s exact value and provides haptic feedback.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The pressure chart includes a dashed \u{201C}You\u{201D} rule so you can spot your sensor against every station at once. Both the map and station list collapse by default — the map always starts closed regardless of previous session state, keeping pins visible when you first open the app.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Device vs station divergence

    private var deviceDeltaSection: some View {
        section(
            icon: "plusminus.circle.fill",
            title: "You vs Stations — Divergence Chart & Pressure Gradient",
            tint: Theme.cyan
        ) {
            Text("The \u{201C}You vs Stations\u{201D} card sits below the station comparison chart and answers a single question with real data: does your barometer agree with the official network? A diverging bar chart is centred on your sensor at zero \u{2014} each nearby NWS station is a signed bar showing exactly how far above or below you it reads. The bars use the same green/amber/orange agreement scale as the station map pins.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The card interprets the pattern, not just the numbers:")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 5) {
                bullet("VERIFIED \u{2014} all stations within \u{00B1}1.5 hPa of your sensor. Your barometer is confirmed against the official network.")
                bullet("DRIFTING \u{2014} all stations read consistently higher (or lower) than you. This usually means altitude or sensor offset, not weather \u{2014} the card nudges you to calibrate in Settings.")
                bullet("DIVERGENT \u{2014} stations disagree with your sensor in different directions. A real pressure gradient is crossing the area.")
            }

            Text("Pressure Gradient Arrow")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 4)

            Text("The card computes the horizontal pressure slope \u{2014} an inverse-distance-weighted vector sum of pressure differences between your device and all reporting stations. When the gradient exceeds 0.8 hPa per 100 km, a compass arrow appears in the card showing which direction pressure is falling toward, because weather systems generally approach from the falling side. This is the same physics meteorologists use to draw isobars on a surface map \u{2014} the tighter the gradient, the stronger the wind and the more organised the system.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Both the divergence chart and gradient arrow are purely spatial \u{2014} they compare your pressure to stations at one moment in time, unlike tendency cards which measure change over hours. Together they tell you whether a feature is near you (spatial) or moving toward you (temporal).")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Observed wind & precipitation

    private var stationObservedSection: some View {
        section(
            icon: "wind.circle.fill",
            title: "Observed Wind & Precipitation",
            tint: Theme.green
        ) {
            Text("The Observed Wind card shows real anemometer data from the nearest reporting NWS station — not forecast-model output. A compass dial displays wind direction; readouts show sustained speed and gusts. The card also compares observed wind against the weather model, flagging when the forecast is off by more than 15 km/h or when wind direction differs by over 45\u{00B0} (a sign of a real front or boundary).")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The Precipitation card combines three data sources: the weather model\u{2019}s current rain rate, the nearest station\u{2019}s rain gauge reading for the last hour, and the 24-hour storm total. Heavy-rain callouts follow standard NWS intensity thresholds (rate \u{2265} 7.6 mm/h, 24h total \u{2265} 50 mm). When everything is dry, the card collapses to a single quiet line.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Station-observed data is labelled \u{201C}STATION DATA\u{201D} or \u{201C}GAUGE + MODEL\u{201D} so you always know whether the number is a real measurement or a model estimate.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Event confirmation

    private var eventConfirmationSection: some View {
        section(
            icon: "bolt.horizontal.circle",
            title: "Extreme Event Confirmation",
            tint: Theme.orange
        ) {
            Text("When the device barometer detects a rapid pressure drop at Storm Watch / Front Imminent level, or the tornado signature activates, the app automatically enters rapid polling mode. It re-checks nearby NWS stations every 5 minutes (instead of waiting for a pull-to-refresh) and compares each station\u{2019}s hour-over-hour pressure trend against your device signal.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("ASOS stations issue special reports (SPECI) during rapid pressure changes, so frequent polling catches them early. The verdict card shows you whether multiple stations confirm the same fall (regional event), only some do (system moving in), or stations are steady (your drop may be hyper-local or sensor noise). The verdict dot\u{2019}s colour matches the confirmation verdict — green for all-clear, amber for partial, red for imminent.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Rapid polling stops automatically when the extreme event clears. The dashboard never pushes notifications based on an unconfirmed signal — it always waits for station cross-validation first.")
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
            Text("On iOS 26 devices with Apple Intelligence, the on-device Foundation Model reads your live sensor data and produces a plain-language briefing. It receives current pressure, trend, tornado signature status, active NWS alerts, weather conditions, CAPE, Lifted Index, lightning strike counts, event confirmation status, rainbow wrap indicator status, the \u{201C}You vs Stations\u{201D} divergence verdict, the pressure gradient arrow direction and strength, and the SPC Day 1 outlook.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything runs on-device \u{2014} no data leaves your iPhone. The insight is probabilistic guidance, not a forecast. On devices without Apple Intelligence, the card shows the standard level description instead.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Background Monitoring

    private var backgroundSection: some View {
        section(
            icon: "moon.zzz.fill",
            title: "Background Monitoring",
            tint: Theme.cyan
        ) {
            Text("When enabled in Settings \u{2192} Alerts & Monitoring, StormScope continues sampling barometric pressure while the app is closed. It uses iOS significant-location-change wakeups — the system wakes the app briefly when you move between cell towers, takes a pressure reading, and puts it back to sleep.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Battery impact is minimal because the barometer sensor draws microwatts and the wakeups are infrequent (typically every few kilometres of movement). Your location data never leaves the device — it is only used to trigger the wakeup. Background monitoring requires a device barometer (iPhone 6 and later).")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Readings collected in the background feed into the trend analyser and chart the next time you open the app, so your pressure history stays continuous. Background monitoring is disabled by default.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Widget & Live Activity

    private var widgetSection: some View {
        section(
            icon: "bolt.badge.clock",
            title: "Lock Screen Live Activity & Home Screen Widget",
            tint: Theme.cyan
        ) {
            Text("StormScope includes two iOS-native glance experiences so you can monitor pressure without opening the app:")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("Lock Screen Live Activity — shows current pressure, trend direction, and storm level on your Lock Screen and in the Dynamic Island. Toggle it on in Settings \u{2192} Alerts & Monitoring.")
                bullet("Home Screen Widget — displays a sparkline of recent pressure readings, the current value, and a trend arrow. Add it from the widget gallery like any other iOS widget.")
            }

            Text("Both update periodically using the same pressure store. The Live Activity requires iOS 16.1+. Neither the widget nor the Live Activity requires the app to be open — they refresh from the background pressure store independently.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Demo Mode

    private var demoSection: some View {
        section(
            icon: "iphone.gen1.slash",
            title: "Demo Mode (No Barometer)",
            tint: Theme.amber
        ) {
            Text("If your device lacks a barometer — iPads, iPod touch, older iPhones, all simulators — StormScope automatically switches to a simulated pressure feed. A notice in Settings explains that barometer-dependent features (background monitoring, sensor calibration, pressure-triggered notifications) are disabled.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The simulated feed varies around 1013 hPa with realistic noise and occasional drops so you can still explore all dashboard features: the gauge, trend chart, tendency cards, tornado analyser, and station comparison. Everything else — NWS alerts, radar, satellite, SPC outlooks, weather data, lightning detection — works identically regardless of barometer availability.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Install StormScope on a barometer-equipped iPhone (iPhone 6 or later) for live pressure readings. The simulated feed is for demonstration only and does not reflect real atmospheric pressure.")
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

    // MARK: - Settings Overview

    private var settingsOverviewSection: some View {
        section(
            icon: "gearshape.fill",
            title: "Settings & Preferences",
            tint: Theme.textSecondary
        ) {
            Text("StormScope\u{2019}s settings are split into five sections so you can tailor every aspect of the app:")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 5) {
                bullet("Measurement Units — temperature/wind metric or imperial; pressure display (hPa, inHg, mmHg, or dual); chart unit (independent hPa/inHg toggle); MSLP on/off.")
                bullet("Alerts & Monitoring — storm and tornado notification toggles; background monitoring; Lock Screen Live Activity; lightning detection on/off.")
                bullet("Sensor Calibration — one-tap alignment to the nearest NWS station; shows active offset and station ID; clear calibration to revert to factory sensor.")
                bullet("Data — shows how many pressure readings are stored; delete all data with confirmation (permanent, cannot be undone).")
                bullet("About — app version; data source acknowledgements (api.weather.gov, spc.noaa.gov, Open-Meteo); device-capability checklist; links to privacy policy and terms.")
            }

            Text("All settings persist across app restarts and are stored only on this device. Nothing is synced or uploaded.")
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
                tip("scope", "Calibrate your barometer to the nearest NWS station from Settings anytime — especially after travelling to a new region or elevation.")
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
