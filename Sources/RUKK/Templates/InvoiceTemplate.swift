import SwiftUI

/// Velur reikningssnið eftir `invoice.templateName` ("icelandic" sjálfgefið, "universal" valkvætt).
enum InvoiceRenderer {
    @MainActor @ViewBuilder
    static func view(for invoice: Invoice, settings: AppSettings) -> some View {
        switch invoice.templateName {
        case "universal": UniversalTemplate(invoice: invoice, settings: settings)
        default: IcelandicTemplate(invoice: invoice, settings: settings)
        }
    }
}
