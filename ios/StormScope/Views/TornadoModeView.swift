import SwiftUI

/// Toggleable "Tornado Signature Mode": tightens the analysis to a 10-minute
/// window looking for abrupt, rotation-scale pressure drops, and fuses the
/// result with official NWS tornado watches/warnings.
struct TornadoModeView: View {
    @Binding var isEnabled: Bool
    let signature: TornadoSignature
    let hasTornadoWarning: Bool
    let hasTornadoWatch: Bool
    let pressureMode: PressureDisplayMode
    var isSimulated: Bool = false

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "tornado")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isEnabled ? statusTint : Theme.textSecondary)
                    .symbolEffect(.variableColor.iterative, isActive: isEnabled && isAlerting)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tornado Signature Mode")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text("10-min micro-drop watch + NWS fusion")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(Theme.orange)
            }

            if isEnabled {
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 9, height: 9)
                        .scaleEffect(isPulsing && isAlerting ? 1.5 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .kerning(0.4)
                        .foregroundStyle(statusTint)
                    Spacer()
                }

                Text(statusDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    metricTile(
                        label: "10-min Δ",
                        value: signature.drop10m.map { pressureMode.deltaFine($0) } ?? "—"
                    )
                    metricTile(
                        label: "Jitter",
                        value: signature.volatility.map { pressureMode.jitter($0) } ?? "—"
                    )
                    metricTile(label: "NWS", value: nwsStatus)
                }

                if !signature.corroborators.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(signature.escalatedByCorroboration ? Theme.red : Theme.amber)
                        Text(corroborationText)
                            .font(.system(size: 10))
                            .foregroundStyle((signature.escalatedByCorroboration ? Theme.red : Theme.amber).opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if signature.isAtmosphereUnstable {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.orange)
                        Text("Unstable atmosphere (CAPE / Lifted Index) — pressure-drop thresholds are tightened.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.orange.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if isSimulated {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber)
                        Text("Micro-pressure analysis is based on demo data — real sensor readings are needed for accurate tornado signatures.")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.amber.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .background(Theme.amber.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
                Text("One barometer can't confirm a tornado — this flags pressure behavior consistent with severe rotation nearby. Always follow official warnings.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [statusTint.opacity(isEnabled && isAlerting ? 0.16 : 0.05), Theme.panel],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isEnabled && isAlerting ? statusTint.opacity(0.55) : Theme.panelStroke, lineWidth: 1)
        )
        .onAppear { isPulsing = true }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isEnabled)
        .sensoryFeedback(.error, trigger: isEnabled && isAlerting)
    }

    // MARK: - Derived status

    private var isAlerting: Bool {
        hasTornadoWarning || signature.status == .signature
    }

    private var statusTint: Color {
        if hasTornadoWarning || signature.status == .signature { return Theme.red }
        if hasTornadoWatch || signature.status == .elevated { return Theme.orange }
        if signature.status == .insufficientData { return Theme.textSecondary }
        return Theme.green
    }

    private var statusTitle: String {
        if hasTornadoWarning { return "NWS TORNADO WARNING ACTIVE" }
        if signature.status == .signature { return "PRESSURE SIGNATURE DETECTED" }
        if hasTornadoWatch { return "NWS TORNADO WATCH" }
        if signature.status == .elevated { return "ELEVATED MICRO-ACTIVITY" }
        if signature.status == .insufficientData { return "COLLECTING SAMPLES" }
        return "NO SIGNATURE"
    }

    private var statusDetail: String {
        if hasTornadoWarning {
            return "An official Tornado Warning covers your location right now. Take shelter immediately — do not wait on sensor data."
        }
        if signature.status == .signature {
            return "Abrupt rotation-scale pressure fall in the last 10 minutes. Check the sky and official alerts now."
        }
        if hasTornadoWatch {
            return "Conditions favor tornado development in your region. Watching the barometer for micro-drops."
        }
        if signature.status == .elevated {
            return "Short-term pressure is unusually active. Not a tornado call — keep an eye on alerts."
        }
        if signature.status == .insufficientData {
            return "Building a 10-minute sample window. Signature analysis starts after a few minutes of readings."
        }
        return "No abrupt micro-drops in the last 10 minutes and no tornado alerts for your area."
    }

    private var corroborationText: String {
        let joined = signature.corroborators.joined(separator: " · ")
        if signature.escalatedByCorroboration {
            return "Status raised early — corroborated by: \(joined)"
        }
        return "Corroborating signals: \(joined)"
    }

    private var nwsStatus: String {
        if hasTornadoWarning { return "Warning" }
        if hasTornadoWatch { return "Watch" }
        return "Clear"
    }

    private func metricTile(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }
}
