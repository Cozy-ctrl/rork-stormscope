import SwiftUI

/// Side-by-side 1-hour and 3-hour pressure tendency cards.
struct TendencyRowView: View {
    let delta1h: Double?
    let delta3h: Double?
    let pressureMode: PressureDisplayMode

    var body: some View {
        HStack(spacing: 12) {
            tendencyCard(label: "1h Change", delta: delta1h)
            tendencyCard(label: "3h Change", delta: delta3h)
        }
    }

    private func tendencyCard(label: String, delta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            HStack(spacing: 6) {
                if let delta {
                    Image(systemName: delta < -0.3 ? "arrow.down.right.circle.fill" : delta > 0.3 ? "arrow.up.right.circle.fill" : "arrow.right.circle.fill")
                        .foregroundStyle(color(for: delta))
                        .font(.system(size: 18))
                    Text(pressureMode.delta(delta))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "hourglass")
                        .foregroundStyle(Theme.textTertiary)
                        .font(.system(size: 16))
                    Text("Pending")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.panelStroke, lineWidth: 1))
    }

    private func color(for delta: Double) -> Color {
        if delta <= -3 { return Theme.red }
        if delta <= -1 { return Theme.orange }
        if delta < -0.3 { return Theme.amber }
        if delta > 0.3 { return Theme.cyan }
        return Theme.green
    }
}
