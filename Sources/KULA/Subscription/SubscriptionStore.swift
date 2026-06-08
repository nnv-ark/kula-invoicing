import Foundation
import StoreKit
import os

/// Heldur utan um áskriftarstöðu appsins (StoreKit 2).
/// KÚLA er „allt læst": appið krefst virkrar áskriftar (með 1 viku fríum reynslutíma).
@MainActor
@Observable
final class SubscriptionStore {

    /// Vörunúmer árs-áskriftar — verður að passa við auto-renewable subscription í App Store Connect.
    static let yearlyProductID = "is.calmail.kula.yearly"

    private(set) var product: Product?
    private(set) var isSubscribed = false
    private(set) var isLoading = true
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let log = Logger(subsystem: "is.calmail.kula", category: "subscription")

    init() {
        // Hlusta á uppfærslur (kaup utan apps, endurnýjun, endurgreiðslur) allan líftímann.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await load() }
    }

    /// Sækir vöruna og uppfærir áskriftarstöðu.
    func load() async {
        isLoading = true
        lastError = nil
        do {
            product = try await Product.products(for: [Self.yearlyProductID]).first
            if product == nil {
                log.error("Subscription product not found: \(Self.yearlyProductID, privacy: .public)")
            }
        } catch {
            log.error("Failed to load products: \(error, privacy: .public)")
            lastError = error.localizedDescription
        }
        await refreshStatus()
        isLoading = false
    }

    /// Kaupir áskriftina (hefur frían reynslutíma ef hann er stilltur í App Store Connect).
    func purchase() async {
        guard let product else { return }
        lastError = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshStatus()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            log.error("Purchase failed: \(error, privacy: .public)")
            lastError = error.localizedDescription
        }
    }

    /// Endurheimtir fyrri kaup (t.d. á nýju tæki eða eftir enduruppsetningu).
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            log.error("Restore failed: \(error, privacy: .public)")
            lastError = error.localizedDescription
        }
        await refreshStatus()
    }

    /// Yfirfer virkar heimildir og uppfærir `isSubscribed`.
    func refreshStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result) else { continue }
            guard transaction.productID == Self.yearlyProductID, transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate {
                if expiration > .now { active = true }
            } else {
                active = true
            }
        }
        isSubscribed = active
    }

    // MARK: - Private

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? verified(result) else { return }
        await transaction.finish()
        await refreshStatus()
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe):       return safe
        }
    }
}
