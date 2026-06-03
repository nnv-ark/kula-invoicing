import Foundation
import SwiftData

/// Eitt fyrirtæki (snið, sjálfgildi, númerakerfi, útlit).
/// Hægt er að hafa mörg og skipta á milli — virkt fyrirtæki er geymt í @AppStorage("activeCompanyID").
@Model
final class AppSettings {
    var id: UUID = UUID()

    // Profile
    var fullName: String = ""
    var companyName: String = ""
    var companyTagline: String = ""        // smátt undir merki, t.d. netfang
    var companyEmail: String = ""
    var companyPhone: String = ""
    var companyWebsite: String = ""
    var companyAddress: String = ""
    var companyNationalID: String = ""     // kennitala
    var companyVATNumber: String = ""      // VSK-númer
    var bankAccountNumber: String = ""     // Reikningsnr. (banki)
    var collectionMethod: String = "Rafrænn reikningur"
    var logoData: Data?

    // Invoice defaults
    var defaultCurrencyCode: String = "ISK"
    var defaultTaxRate: Decimal = 24
    var defaultPaymentTermDays: Int = 14
    var defaultTemplate: String = "icelandic"
    var defaultNote: String = ""
    var dateFormat: String = "medium"  // short | medium | long

    // Invoice numbering
    var invoiceNumberPrefix: String = ""
    var nextInvoiceNumber: Int = 1

    // Útlit / leturgerð (typography & layout)
    var logoScale: Double = 1.0            // 0.5–2.0, margfaldari á logo-stærð
    var fontName: String = ""              // tómt = kerfisletur
    var baseFontSize: Double = 10          // grunnletur reiknings
    var headingFontSize: Double = 32       // fyrirsögn / logo-texti
    var textColorHex: String = "#000000"
    var paperSize: String = "a4"           // a4 | letter

    init() {}

    /// Nafn til að sýna í fyrirtækjavalmynd.
    var displayName: String {
        companyName.isEmpty ? (fullName.isEmpty ? "Ónefnt fyrirtæki" : fullName) : companyName
    }

    /// Öll fyrirtæki, raðað eftir nafni.
    @MainActor
    static func all(in context: ModelContext) -> [AppSettings] {
        (try? context.fetch(FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.companyName)]))) ?? []
    }

    /// Tryggir að a.m.k. eitt fyrirtæki sé til og skilar virku fyrirtæki.
    /// `activeID` er uuidString úr @AppStorage; tómt/ófundið → fyrsta fyrirtæki.
    /// Kallast aðeins úr action-handlerum eða `.task`, aldrei úr `body`.
    @MainActor
    static func active(in context: ModelContext, activeID: String) -> AppSettings {
        let companies = all(in: context)
        if let match = companies.first(where: { $0.id.uuidString == activeID }) {
            return match
        }
        if let first = companies.first { return first }
        let created = AppSettings()
        context.insert(created)
        return created
    }
}
