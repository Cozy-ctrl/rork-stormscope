import SwiftUI
import RevenueCat

/// Dark, storm-themed paywall for the one-time StormScope Pro lifetime
/// unlock. Lists the packages from the current RevenueCat offering and
/// always exposes Restore Purchases (App Store review requirement).
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

            Text("Everything. Forever. Once.")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("One purchase unlocks StormScope Pro on this device for life — no subscription, no renewals.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Value list

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
        VStack(spacing: 16) {
            valueList
            ForEach(offering.availablePackages, id: \.identifier) { package in
                purchaseButton(package)
            }
            freeForeverNote
        }
    }

    private func purchaseButton(_ package: Package) -> some View {
        Button {
            Task { await store.purchase(package: package) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Pay once. Never again.")
                        .font(.system(size: 11))
                        .opacity(0.85)
                }
                Spacer()
                if store.isPurchasing {
                    ProgressView()
                        .tint(Theme.inkDeep)
                } else {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Theme.inkDeep)
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Theme.cyan, Theme.cyan.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(.rect(cornerRadius: 16))
        }
        .disabled(store.isPurchasing)
        .accessibilityHint("Unlocks all StormScope Pro features permanently")
    }

    private var unavailableSection: some View {
        VStack(spacing: 12) {
            valueList
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
        Text("Payment is charged to your Apple ID at confirmation. StormScope Pro is a one-time purchase — it never expires or renews. Manage purchases in your App Store account settings.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textTertiary.opacity(0.8))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }
}

#Preview {
    PaywallView(store: StoreViewModel())
}
