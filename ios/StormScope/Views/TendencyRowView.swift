import SwiftUI

/// Three‑column pressure tendency cards showing 1‑hour, 3‑hour and 6‑hour
/// deltas so the user can spot short‑, medium‑ and longer‑term pressure
/// trends at a glance.
struct TendencyRowView: View {
    let delta1h: Double?
    let delta3h: Double?
    let delta6h: Double?
    let pressureMode: PressureDisplayMode

    var body: some View {
        HStack(spacing: 10) {
            tendencyCard(label: "1h", delta: delta1h)
            tendencyCard(label: "3h", delta: delta3h)
            tendencyCard(label: "6h", delta: delta6h)
        }
    }

    private func tendencyCard(label: String, delta: Double?) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(1)

            if let delta {
                Image(systemName: delta < -0.3 ? "arrow.down.right.circle.fill" : delta > 0.3 ? "arrow.up.right.circle.fill" : "arrow.right.circle.fill")
                    .foregroundStyle(color(for: delta))
                    .font(.system(size: 16))
                Text(pressureMode.delta(delta))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Image(systemName: "hourglass")
                    .foregroundStyle(Theme.textTertiary)
                    .font(.system(size: 14))
                Text("…")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.panelStroke, lineWidth: 1))
    }

    private func color(for delta: Double) -> Color {
        if delta <= -3 { return Theme.red }
        if delta <= -1 { return Theme.orange }
        if delta < -0.3 { return Theme.amber }
        if delta > 0.3 { return Theme.cyan }
        return Theme.green
    }
}
