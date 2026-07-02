import SwiftUI

/// SPC Day 1–3 convective outlook for the user's exact point: categorical
/// risk badge plus tornado/hail/wind probabilities.
struct OutlookCardView: View {
    let outlooks: [SPCOutlook]
    let isLoading: Bool

    @State private var selectedDay: Int = 1

    private var selected: SPCOutlook? {
        outlooks.first { $0.day == selectedDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
                Text("SPC Severe Outlook")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("spc.noaa.gov")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Picker("Outlook day", selection: $selectedDay) {
                Text("Day 1").tag(1)
                Text("Day 2").tag(2)
                Text("Day 3").tag(3)
            }
            .pickerStyle(.segmented)

            if let selected {
                content(for: selected)
            } else if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.cyan)
                    Text("Checking the Storm Prediction Center…")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                Text("Outlook data unavailable — SPC outlooks cover the continental U.S.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: selectedDay)
    }

    private func content(for outlook: SPCOutlook) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(outlook.categoryShort)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .kerning(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(outlook.tint.opacity(0.18))
                    .foregroundStyle(outlook.tint)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(outlook.tint.opacity(0.5), lineWidth: 1))

                Text(outlook.categoryTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(outlook.categoryCode == nil ? Theme.textSecondary : Theme.textPrimary)
                Spacer()
            }

            Text(outlook.summary)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if hasHazards(outlook) {
                HStack(spacing: 8) {
                    if let tornado = outlook.tornadoProbability {
                        hazardChip("tornado", "Tornado \(tornado)%", tornado >= 5 ? Theme.red : Theme.amber)
                    }
                    if let hail = outlook.hailProbability {
                        hazardChip("cloud.hail.fill", "Hail \(hail)%", Theme.cyan)
                    }
                    if let wind = outlook.windProbability {
                        hazardChip("wind", "Wind \(wind)%", Theme.orange)
                    }
                    if let severe = outlook.severeProbability {
                        hazardChip("exclamationmark.triangle.fill", "Severe \(severe)%", Theme.orange)
                    }
                }
            }
        }
    }

    private func hasHazards(_ outlook: SPCOutlook) -> Bool {
        outlook.tornadoProbability != nil
            || outlook.hailProbability != nil
            || outlook.windProbability != nil
            || outlook.severeProbability != nil
    }

    private func hazardChip(_ icon: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview {
    ZStack {
        Theme.ink.ignoresSafeArea()
        OutlookCardView(
            outlooks: [
                SPCOutlook(day: 1, categoryCode: 5, tornadoProbability: 10, hailProbability: 30, windProbability: 30, severeProbability: nil),
                SPCOutlook(day: 2, categoryCode: 3, tornadoProbability: 2, hailProbability: 5, windProbability: 5, severeProbability: nil),
                SPCOutlook(day: 3, categoryCode: nil, tornadoProbability: nil, hailProbability: nil, windProbability: nil, severeProbability: nil),
            ],
            isLoading: false
        )
        .padding()
    }
}
