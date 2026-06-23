import Foundation
import Observation

/// Gögn sem berast utanfrá (t.d. úr Tyme-viðbót) gegnum `rukk://` slóð til að búa til drög-reikning.
struct InvoiceImportPayload: Codable, Equatable {
    struct Line: Codable, Equatable {
        let description: String
        let quantity: Decimal
        let unitPrice: Decimal
        var unit: String?       // t.d. "klst" — eingöngu til upplýsingar
    }
    var version: Int = 1
    var source: String?          // t.d. "tyme"
    var currency: String?        // t.d. "ISK"
    var customer: String?        // verkefnaheiti úr upprunanum (valkvætt)
    var lines: [Line]
}

/// Les `rukk://invoice?data=<base64 JSON>` slóðir og afkóðar í `InvoiceImportPayload`.
enum InvoiceImport {
    static func payload(from url: URL) -> InvoiceImportPayload? {
        guard url.scheme?.lowercased() == "rukk" else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encoded = comps.queryItems?.first(where: { $0.name == "data" })?.value,
              let data = decodeBase64(encoded) else { return nil }
        return try? JSONDecoder().decode(InvoiceImportPayload.self, from: data)
    }

    /// Tekur við bæði venjulegu og URL-öruggu base64 (og vantandi „=“ fyllingu).
    private static func decodeBase64(_ string: String) -> Data? {
        var s = string.replacingOccurrences(of: "-", with: "+")
                      .replacingOccurrences(of: "_", with: "/")
        let pad = s.count % 4
        if pad > 0 { s += String(repeating: "=", count: 4 - pad) }
        return Data(base64Encoded: s)
    }
}

/// Geymir reikning sem bíður þess að vera búinn til þegar aðalviðmótið birtist.
/// Fyllt af `.onOpenURL`, tæmt af `ContentView`.
@Observable
final class ImportInbox {
    var pending: InvoiceImportPayload?
}
