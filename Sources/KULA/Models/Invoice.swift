import Foundation
import SwiftData

@Model
final class Invoice {
    var number: String = ""
    var issueDate: Date = Date()
    var dueDate: Date?
    var paymentTermDays: Int?
    var currencyCode: String = "ISK"
    var taxRate: Decimal = 24         // sjálfgefið VSK fyrir nýjar línur
    var isTaxInclusive: Bool = false
    var discountAmount: Decimal = 0
    var discountIsPercent: Bool = false
    var note: String = ""
    var statusRaw: String = InvoiceStatus.draft.rawValue
    var createdAt: Date = Date()
    var templateName: String = "icelandic"
    var collectionMethod: String = "Rafrænn reikningur"
    var bookingDate: Date?            // Bókunardagur (sjálfgefið = issueDate)
    var printedAt: Date?              // sett þegar reikningur er prentaður/fluttur út
    var paidAt: Date?                 // sett þegar staða verður „Greitt" (fyrir greiðsluhraða)

    var isPrinted: Bool { printedAt != nil }

    var recipient: Contact?

    /// Fyrirtækið sem gaf reikninginn út (fast við útgáfu svo gamlir reikningar breytast ekki).
    var issuer: AppSettings?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.invoice)
    var lineItems: [LineItem] = []

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set {
            statusRaw = newValue.rawValue
            if newValue == .paid {
                if paidAt == nil { paidAt = .now }
            } else {
                paidAt = nil
            }
        }
    }

    /// Greiðsluhraði í dögum (frá útgáfu til greiðslu), ef greitt.
    var paymentDays: Int? {
        guard let paidAt else { return nil }
        return Calendar.current.dateComponents([.day], from: issueDate, to: paidAt).day
    }

    init(number: String = "", currencyCode: String = "ISK", taxRate: Decimal = 0) {
        self.number = number
        self.currencyCode = currencyCode
        self.taxRate = taxRate
        self.issueDate = .now
        self.createdAt = .now
    }

    /// Býr til, stillir og setur inn nýjan reikning fyrir tiltekið fyrirtæki.
    /// Reikningsnúmer fyrirtækis: forskeyti + núll-fyllt 3-stafa númer (001, 002, …).
    static func formattedNumber(prefix: String, _ n: Int) -> String {
        "\(prefix)\(String(format: "%03d", n))"
    }

    @MainActor
    static func makeNext(in context: ModelContext, company: AppSettings) -> Invoice {
        let invoice = Invoice(number: formattedNumber(prefix: company.invoiceNumberPrefix, company.nextInvoiceNumber),
                              currencyCode: company.defaultCurrencyCode,
                              taxRate: company.defaultTaxRate)
        invoice.issuer = company
        invoice.paymentTermDays = company.defaultPaymentTermDays
        invoice.templateName = company.defaultTemplate
        invoice.note = company.defaultNote
        invoice.collectionMethod = company.collectionMethod
        invoice.bookingDate = invoice.issueDate
        if let term = invoice.paymentTermDays {
            invoice.dueDate = Calendar.current.date(byAdding: .day, value: term, to: invoice.issueDate)
        }
        context.insert(invoice)
        company.nextInvoiceNumber += 1
        return invoice
    }

    // MARK: - Computed totals

    var orderedItems: [LineItem] {
        lineItems.sorted { $0.order < $1.order }
    }

    var subtotal: Decimal {                                  // samtals án VSK
        lineItems.reduce(0) { $0 + $1.subtotal }
    }

    var discountValue: Decimal {
        discountIsPercent ? (subtotal * discountAmount / 100) : discountAmount
    }

    var taxableBase: Decimal { subtotal - discountValue }

    var taxValue: Decimal {                                  // heildar VSK (summa per-línu)
        lineItems.reduce(0) { $0 + $1.taxAmount }
    }

    var total: Decimal { taxableBase + taxValue }            // samtals með VSK

    /// Sundurliðun VSK eftir hlutfalli: [(hlutfall%, grunnur án VSK, VSK upphæð)]
    var vatBreakdown: [(rate: Decimal, base: Decimal, tax: Decimal)] {
        let grouped = Dictionary(grouping: lineItems, by: { $0.taxRate })
        return grouped
            .map { rate, items in
                let base = items.reduce(Decimal(0)) { $0 + $1.subtotal }
                let tax = items.reduce(Decimal(0)) { $0 + $1.taxAmount }
                return (rate, base, tax)
            }
            .sorted { $0.rate < $1.rate }
    }
}
