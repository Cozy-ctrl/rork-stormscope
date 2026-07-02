import ActivityKit
import WidgetKit
import SwiftUI

/// Lock screen + Dynamic Island presentation of the live pressure trend.
struct StormScopeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StormActivityAttributes.self) { context in
            LockScreenActivityView(state: context.state)
                .activityBackgroundTint(Color(red: 0.016, green: 0.027, blue: 0.055))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: StormStyle.icon(for: context.state.levelRaw))
                            .font(.system(size: 13, weight: .semibold))
                        Text(StormStyle.title(for: context.state.levelRaw))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(StormStyle.tint(for: context.state.levelRaw))
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(StormStyle.pressureText(context.state.pressureHPa, imperial: context.state.usesImperial))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(StormStyle.pressureUnit(imperial: context.state.usesImperial))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        SparklineShape(samples: context.state.sparkline)
                            .stroke(
                                StormStyle.tint(for: context.state.levelRaw),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                            .frame(height: 26)
                            .padding(.horizontal, 6)
                        HStack {
                            if let rate = context.state.ratePerHour {
                                Text(StormStyle.rateText(rate, imperial: context.state.usesImperial))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(StormStyle.tint(for: context.state.levelRaw))
                            }
                            Spacer()
                            if context.state.hasTornadoWarning {
                                Label("TORNADO WARNING", systemImage: "tornado")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))
                            } else if context.state.alertCount > 0 {
                                Text("\(context.state.alertCount) NWS alert\(context.state.alertCount == 1 ? "" : "s")")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(context.state.updatedAt, style: .relative)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                }
            } compactLeading: {
                Image(systemName: StormStyle.icon(for: context.state.levelRaw))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StormStyle.tint(for: context.state.levelRaw))
            } compactTrailing: {
                Text(StormStyle.pressureText(context.state.pressureHPa, imperial: context.state.usesImperial))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(StormStyle.tint(for: context.state.levelRaw))
            } minimal: {
                Image(systemName: StormStyle.icon(for: context.state.levelRaw))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(StormStyle.tint(for: context.state.levelRaw))
            }
        }
    }
}

/// Full lock screen banner.
private struct LockScreenActivityView: View {
    let state: StormActivityAttributes.ContentState

    private var tint: Color {
        StormStyle.tint(for: state.levelRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: StormStyle.icon(for: state.levelRaw))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(StormStyle.title(for: state.levelRaw))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                if state.hasTornadoWarning {
                    Text("TORNADO WARNING")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .kerning(0.5)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(red: 1.0, green: 0.36, blue: 0.36).opacity(0.25))
                        .foregroundStyle(Color(red: 1.0, green: 0.36, blue: 0.36))
                        .clipShape(Capsule())
                } else {
                    Text(state.updatedAt, style: .relative)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(StormStyle.pressureText(state.pressureHPa, imperial: state.usesImperial))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(StormStyle.pressureUnit(imperial: state.usesImperial))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let rate = state.ratePerHour {
                            Text(StormStyle.rateText(rate, imperial: state.usesImperial))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(tint)
                        }
                    }
                }
                SparklineShape(samples: state.sparkline)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
        }
        .padding(14)
    }
}
