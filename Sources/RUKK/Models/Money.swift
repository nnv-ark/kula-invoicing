import Foundation

enum Money {
    /// Notað fyrir upphæðir í viðmótinu (mælaborð, listar) — fylgir viðmótsmálinu.
    /// Reikningurinn sjálfur (PDF) er algjörlega óháður og notar `InvoiceStrings` í staðinn.
    static func format(_ amount: Decimal, currencyCode: String) -> String {
        let f = NumberFormatter()
        f.locale = AppLanguage.currentUI.locale
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        return f.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
    }
}
