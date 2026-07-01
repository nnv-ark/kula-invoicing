import SwiftUI
import StoreKit

/// Áskriftarskjár — sýndur þegar engin virk áskrift er. Lokar á allt appið.
struct PaywallView: View {
    let store: SubscriptionStore
    @State private var isWorking = false
    /// DEBUG-only: sami lykill og RootView les til að sleppa paywall við prófun.
    @AppStorage("debugUnlocked") private var debugUnlocked = false

    /// Útgáfunúmer + útgefandi, til að sýna smátt neðst.
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Útgáfa \(version) (\(build))  ·  © 2026 NNV.ehf"
    }

    private let features: [(icon: String, text: LocalizedStringKey)] = [
        ("building.2", "Mörg fyrirtæki? Ekkert mál! Auðvelt að skipta á milli — og kostar ekki aukalega."),
        ("chart.bar.xaxis", "Mælaborð: sala, innheimt, útistandandi og greiðsluhraði — meiri upplýsingar á leiðinni."),
        ("arrow.up.doc", "XML-stuðningur og auðvelt að flytja allt út í einu.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image("Logo")
                .resizable().scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .shadow(radius: 8, y: 4)

            Text("RUKK")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 12)
            Text("Reikningagerð fyrir íslensk fyrirtæki og verktaka")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.icon) { feature in
                    Label {
                        Text(feature.text)
                    } icon: {
                        Image(systemName: feature.icon)
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                    }
                    .font(.body)
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 12)

            purchaseSection
                .frame(maxWidth: 420)

            Spacer(minLength: 16)

            #if DEBUG
            Button("Halda áfram án áskriftar (DEBUG)") { debugUnlocked = true }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.bottom, 2)
            #endif

            Text(versionLine)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if store.isLoading {
            ProgressView().controlSize(.large)
        } else if let product = store.product {
            let trial = store.trialEligible && hasFreeTrial(product)
            buySection(showTrial: trial, disclosure: disclosure(for: product, showTrial: trial))
        } else {
            #if DEBUG
            if Demo.showPaywall {
                buySection(showTrial: true, disclosure: "Ókeypis í 1 viku, svo 1.490 kr. á ári. Endurnýjast sjálfkrafa þar til þú segir upp í App Store. Hægt að segja upp hvenær sem er.")
            } else {
                errorSection
            }
            #else
            errorSection
            #endif
        }
    }

    private func buySection(showTrial: Bool, disclosure: String) -> some View {
        VStack(spacing: 12) {
            Button {
                Task { isWorking = true; await store.purchase(); isWorking = false }
            } label: {
                VStack(spacing: 2) {
                    Text("KAUPA")
                        .font(.headline)
                    if showTrial {
                        Text("prófa frítt í eina viku")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking)

            Text(disclosure)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button("Endurheimta kaup") { Task { await store.restore() } }
                    .disabled(isWorking)
                Link("Persónuvernd", destination: URL(string: "https://github.com/nnv-ark/kula-invoicing/blob/main/PRIVACY.md")!)
                Link("Skilmálar", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption)
        }
    }

    private var errorSection: some View {
        VStack(spacing: 10) {
            Text("Tókst ekki að sækja áskriftina.")
                .foregroundStyle(.secondary)
            if let err = store.lastError {
                Text(err).font(.caption).foregroundStyle(.secondary)
            }
            Button("Reyna aftur") { Task { await store.load() } }
                .buttonStyle(.bordered)
        }
    }

    // MARK: - Texti

    private func disclosure(for product: Product, showTrial: Bool) -> String {
        let price = product.displayPrice
        if showTrial {
            return "Ókeypis í 1 viku, svo \(price) á ári. Endurnýjast sjálfkrafa þar til þú segir upp í App Store. Hægt að segja upp hvenær sem er."
        }
        return "\(price) á ári. Endurnýjast sjálfkrafa þar til þú segir upp í App Store. Hægt að segja upp hvenær sem er."
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}
