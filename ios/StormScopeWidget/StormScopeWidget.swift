import WidgetKit
import SwiftUI

nonisolated struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PressureEntry {
        PressureEntry(date: .now, snapshot: PressureEntry.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PressureEntry) -> Void) {
        completion(PressureEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? PressureEntry.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PressureEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        let entry = PressureEntry(date: .now, snapshot: snapshot)
        // When there is no data yet, retry aggressively so the widget fills in
        // soon after first launch. Once populated, fall back to a 15-min cadence
        // since the app pushes reloads on every snapshot save.
        let retrySeconds: TimeInterval = snapshot == nil ? 15 : 15 * 60
        let next = Date().addingTimeInterval(retrySeconds)
        print("[Widget] getTimeline: snapshot=\(snapshot != nil ? "loaded" : "nil"), next refresh in \(Int(retrySeconds))s")
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

nonisolated struct PressureEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    static let sample = WidgetSnapshot(
        pressureHPa: 1013.2,
        ratePerHour: -1.1,
        delta1h: -1.0,
        levelRaw: 3,
        levelTitle: "Change Coming",
        sparkline: [1016.1, 1015.8, 1015.4, 1015.1, 1014.6, 1014.2, 1013.8, 1013.5, 1013.2],
        usesImperial: false,
        updatedAt: .now
    )
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium:
                mediumView(snapshot)
            default:
                smallView(snapshot)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "barometer")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Open StormScope to start tracking pressure")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func smallView(_ snapshot: WidgetSnapshot) -> some View {
        let tint = StormStyle.tint(for: snapshot.levelRaw)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: StormStyle.icon(for: snapshot.levelRaw))
                    .font(.system(size: 12, weight: .semibold))
                Text(snapshot.levelTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(tint)

            Spacer(minLength: 0)

            Text(StormStyle.pressureText(snapshot.pressureHPa, imperial: snapshot.usesImperial))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(StormStyle.pressureUnit(imperial: snapshot.usesImperial))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            if let rate = snapshot.ratePerHour {
                HStack(spacing: 3) {
                    Image(systemName: rate < -0.3 ? "arrow.down.right" : rate > 0.3 ? "arrow.up.right" : "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(StormStyle.rateText(rate, imperial: snapshot.usesImperial))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mediumView(_ snapshot: WidgetSnapshot) -> some View {
        let tint = StormStyle.tint(for: snapshot.levelRaw)
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Image(systemName: StormStyle.icon(for: snapshot.levelRaw))
                        .font(.system(size: 12, weight: .semibold))
                    Text(snapshot.levelTitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(tint)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(StormStyle.pressureText(snapshot.pressureHPa, imperial: snapshot.usesImperial))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(StormStyle.pressureUnit(imperial: snapshot.usesImperial))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if let rate = snapshot.ratePerHour {
                    HStack(spacing: 3) {
                        Image(systemName: rate < -0.3 ? "arrow.down.right" : rate > 0.3 ? "arrow.up.right" : "arrow.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(StormStyle.rateText(rate, imperial: snapshot.usesImperial))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(tint)
                }
            }

            VStack(alignment: .trailing, spacing: 4) {
                Text("6H TREND")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                SparklineShape(samples: snapshot.sparkline)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text(snapshot.updatedAt, style: .relative)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct StormScopeWidget: Widget {
    let kind: String = "StormScopeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.016, green: 0.027, blue: 0.055),
                            Color(red: 0.043, green: 0.063, blue: 0.110),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .environment(\.colorScheme, .dark)
        }
        .configurationDisplayName("Pressure Trend")
        .description("Live barometric pressure, trend, and storm status from your iPhone's sensor.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
