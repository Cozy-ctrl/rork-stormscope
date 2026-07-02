import SwiftUI

/// Surfaces the deterministic rainbow forecast: when solar geometry and live
/// precipitation line up, tells the user exactly where to look. Also carries
/// the "rainbow wrap" secondary severe-rotation indicator for chasers.
struct RainbowCardView: View {
    let forecast: RainbowForecast

    private var verdictLabel: String {
        switch forecast.verdict {
        case .likely: return "LIKELY NOW"
        case .possible: return "POSSIBLE"
        case .sunTooHigh: return "SUN TOO HIGH"
        case .night: return "AFTER SUNRISE"
        case .noRain: return "NO RAIN"
        case .sunObscured: return "OVERCAST"
        }
    }

    private var verdictColor: Color {
        switch forecast.verdict {
        case .likely: return Theme.green
        case .possible: return Theme.amber
        default: return Theme.textTertiary
        }
    }

    private var insightText: String {
        switch forecast.verdict {
        case .likely:
            return "Sun is at \(Int(forecast.sunElevation))° — below the 42° geometric limit — with rain in the area and enough breaks in the cloud for direct sunlight. Put the sun at your back and scan the opposite horizon."
        case .possible:
            let cloudNote = (forecast.cloudCover ?? 0) >= 75 ? "Cloud cover is heavy, so the sun needs to find a gap." : "Rain is close by rather than overhead."
            return "Geometry works — sun at \(Int(forecast.sunElevation))°, below the 42° limit. \(cloudNote) Worth a glance if light suddenly breaks through."
        case .sunTooHigh:
            return "The sun is above 42° elevation, so no rainbow can be seen from the ground right now regardless of rain. Check again later in the afternoon."
        case .night:
            return "The sun is below the horizon. Rainbow optics resume after sunrise."
        case .noRain:
            return "No precipitation detected nearby — a rainbow needs sunlit raindrops."
        case .sunObscured:
            return "Overcast is too thick for direct sunlight to reach the raindrops."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if forecast.verdict == .likely || forecast.verdict == .possible {
                lookRow
            }

            Text(insightText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if forecast.isWrapIndicatorActive {
                wrapRow
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    forecast.isWrapIndicatorActive ? Theme.red.opacity(0.45) : Theme.panelStroke,
                    lineWidth: 1
                )
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "rainbow")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(rainbowGradient)
                .symbolRenderingMode(.monochrome)
            Text("Rainbow Watch")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(verdictLabel)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(1)
                .foregroundStyle(verdictColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(verdictColor.opacity(0.14))
                .clipShape(Capsule())
        }
    }

    private var lookRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.panelStroke, lineWidth: 1)
                    .frame(width: 52, height: 52)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(rainbowGradient)
                    .rotationEffect(.degrees(forecast.lookAzimuth))
                Text("N")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .offset(y: -31)
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("Look \(forecast.lookDirectionName) — \(Int(forecast.lookAzimuth))°")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(String(format: "Bow top ~%.0f° above the horizon \u{00B7} sun behind you at %.0f°", forecast.arcTopElevation, forecast.sunAzimuth))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var wrapRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "tornado")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.red)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rainbow wrap check")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.red)
                Text("Rotation-scale pressure behaviour is active while rainbow optics are possible. A bow appearing inside the rain curtain — especially at an unexpected bearing — can indicate precipitation wrapping around an organised updraft. Treat as a secondary signal; follow official warnings.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.red.opacity(0.08))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var rainbowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.45, blue: 0.40),
                Color(red: 0.98, green: 0.75, blue: 0.35),
                Color(red: 0.45, green: 0.85, blue: 0.55),
                Color(red: 0.40, green: 0.65, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
