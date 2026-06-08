import SwiftUI
import StoreKit

/// Áskriftarskjár — sýndur þegar engin virk áskrift er. Lokar á allt appið.
struct PaywallView: View {
    let store: SubscriptionStore
    @State private var isWorking = false

    private let features: [(icon: String, text: String)] = [
        ("doc.text", "Íslenskt reikningssnið með VSK, PDF og lögboðnum fæti"),
        ("building.2", "Mörg fyrirtæki — skiptu á milli með einum smelli"),
        ("chart.bar.xaxis", "Mælaborð: sala, innheimt, útistandandi og greiðsluhraði"),
        ("arrow.up.doc", "Rafrænn reikningur (UBL / TS-136 / PEPPOL) og fjöldaútflutningur"),
        ("lock.shield", "Öll gögn staðbundin á Mac-tölvunni — ekkert ský")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Image("Logo")
                .resizable().scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(radius: 8, y: 4)

            Text("KÚLA")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 12)
            Text("Reikningagerð fyrir íslensk fyrirtæki")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.text) { feature in
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

            Spacer(minLength: 24)
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
            VStack(spacing: 12) {
                Button {
                    Task { isWorking = true; await store.purchase(); isWorking = false }
                } label: {
                    Text(ctaTitle(for: product))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isWorking)

                Text(disclosure(for: product))
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
        } else {
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
    }

    // MARK: - Texti

    private func ctaTitle(for product: Product) -> String {
        if hasFreeTrial(product) {
            return "Hefja — 1 vika frí"
        }
        return "Gerast áskrifandi — \(product.displayPrice)/ár"
    }

    private func disclosure(for product: Product) -> String {
        let price = product.displayPrice
        if hasFreeTrial(product) {
            return "Ókeypis í 1 viku, svo \(price) á ári. Endurnýjast sjálfkrafa þar til þú segir upp í App Store. Hægt að segja upp hvenær sem er."
        }
        return "\(price) á ári. Endurnýjast sjálfkrafa þar til þú segir upp í App Store."
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}
