import SwiftUI
import RevenueCat

/// Dark, storm-themed paywall for StormScope Pro. Shows every plan in the
/// current RevenueCat offering (monthly, annual, lifetime) and always exposes
/// Restore Purchases (App Store review requirement).
struct PaywallView: View {
    var store: StoreViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    if let current = store.offerings?.current {
                        packagesSection(current)
                    } else if store.isLoading {
                        ProgressView()
                            .tint(Theme.cyan)
                            .padding(.vertical, 40)
                    } else {
                        unavailableSection
                    }
                    restoreSection
                    legalFootnote
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            .navigationTitle("StormScope Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.cyan)
                }
            }
            .alert("Purchase Error", isPresented: .init(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )) {
                Button("OK") { store.errorMessage = nil }
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.cyan.opacity(0.25), Theme.cyan.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Theme.cyan)
            }
            .accessibilityHidden(true)

            Text(heroTitle)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text(heroSubtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Headline adapts to where the user is in the trial lifecycle.
    private var heroTitle: String {
        if store.isPremium { return "You own StormScope Pro" }
        if store.isTrialActive { return "Enjoy 7 days of Premium" }
        return "Unlock StormScope Pro"
    }

    private var heroSubtitle: String {
        if store.isPremium {
            return "Pro is active on this device — thanks for supporting StormScope."
        }
        if store.isTrialActive {
            let days = store.trialDaysRemaining
            let suffix = days == 1 ? "day" : "days"
            return "Explore the full feature set free for \(days) more \(suffix). Pick a plan anytime to keep everything."
        }
        return "Monthly, yearly, or a single lifetime payment — every plan unlocks all Pro features on this device."
    }

    // MARK: - Value list

    /// Upfront transparency: during the trial we say exactly what locks when
    /// it ends, instead of surprising the user on day 8.
    private var gatedList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.isTrialActive ? "When your free trial ends, these lock:" : "StormScope Pro unlocks:")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(store.isTrialActive ? Theme.amber : Theme.textSecondary)
                .padding(.horizontal, 4)
            valueList
        }
    }

    private var valueList: some View {
        VStack(alignment: .leading, spacing: 14) {
            perkRow("apple.intelligence", tint: Theme.cyan,
                    title: "Live Feedback",
                    message: "On-device AI analysis of your pressure trend")
            perkRow("antenna.radiowaves.left.and.right", tint: Theme.cyan,
                    title: "Radar & SPC Outlook",
                    message: "NEXRAD imagery and Storm Prediction Center day outlooks")
            perkRow("square.and.arrow.up", tint: Theme.cyan,
                    title: "Data Export & Reports",
                    message: "CSV/JSON exports and branded shareable storm reports")
        }
        .padding(16)
        .background(Theme.panel)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.panelStroke, lineWidth: 1))
    }

    private func perkRow(_ icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var freeForeverNote: some View {
        Label {
            Text("Always free: pressure gauge, storm assessment, NWS alerts, and lightning detection.")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.seal.fill")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.green)
        .padding(.horizontal, 4)
    }

    // MARK: - Packages

    private func packagesSection(_ offering: Offering) -> some View {
        let plans = sortedPlans(offering)
        return VStack(spacing: 16) {
            gatedList
            ForEach(Array(plans.enumerated()), id: \.element.identifier) { index, package in
                planButton(package, isPrimary: index == 0)
            }
            freeForeverNote
        }
    }

    /// Annual first (best value), then lifetime, then monthly.
    private func sortedPlans(_ offering: Offering) -> [Package] {
        offering.availablePackages.sorted { planRank($0) < planRank($1) }
    }

    private func planRank(_ package: Package) -> Int {
        let id = package.identifier.lowercased()
        if id.contains("annual") || id.contains("yearly") { return 0 }
        if id.contains("lifetime") || id.contains("forever") { return 1 }
        return 2
    }

    private func planSubtitle(_ package: Package) -> String {
        let id = package.identifier.lowercased()
        if id.contains("annual") || id.contains("yearly") {
            return "Billed yearly · Save 44% vs monthly"
        }
        if id.contains("monthly") { return "Billed monthly · Cancel anytime" }
        if id.contains("lifetime") || id.contains("forever") {
            return "One-time payment · Never renews"
        }
        return ""
    }

    private func planButton(_ package: Package, isPrimary: Bool) -> some View {
        Button {
            Task { await store.purchase(package: package) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(package.storeProduct.localizedTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        if isPrimary { bestValueBadge }
                    }
                    if !planSubtitle(package).isEmpty {
                        Text(planSubtitle(package))
                            .font(.system(size: 11))
                            .opacity(0.85)
                    }
                }
                Spacer()
                if store.isPurchasing {
                    ProgressView()
                        .tint(isPrimary ? Theme.inkDeep : Theme.cyan)
                } else {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(isPrimary ? Theme.inkDeep : Theme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [Theme.cyan, Theme.cyan.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(.rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isPrimary ? Color.clear : Theme.cyan.opacity(0.4), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.panel)
                    .opacity(isPrimary ? 0 : 1)
            )
        }
        .disabled(store.isPurchasing)
        .accessibilityHint("Unlocks all StormScope Pro features")
    }

    private var bestValueBadge: some View {
        Text("BEST VALUE")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .kerning(0.5)
            .foregroundStyle(Theme.inkDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Theme.inkDeep.opacity(0.15))
            .clipShape(Capsule())
    }

    private var unavailableSection: some View {
        VStack(spacing: 12) {
            gatedList
            Text(store.errorMessage ?? "The purchase store couldn't be reached. Check your connection and try again.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await store.fetchOfferings() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .tint(Theme.cyan)
        }
    }

    // MARK: - Restore & legal

    private var restoreSection: some View {
        VStack(spacing: 6) {
            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .tint(Theme.cyan)

            if let price = store.lifetimePrice {
                Text("Lifetime unlock — \(price), one time.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    private var legalFootnote: some View {
        VStack(spacing: 10) {
            Text("Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically until cancelled in your App Store account settings; the lifetime plan is a one-time charge that never renews.")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary.opacity(0.8))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: LegalLinks.terms)
                Text("·")
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
                Link("Privacy Policy", destination: LegalLinks.privacy)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tint(Theme.cyan)
            .accessibilityElement(children: .contain)
        }
    }
}

#Preview {
    PaywallView(store: StoreViewModel())
}
