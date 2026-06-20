import SwiftUI

/// Eina reikningssniðið — íslenskt. (Áður voru fleiri sniðmát; einfaldað í eitt.)
enum InvoiceRenderer {
    @MainActor @ViewBuilder
    static func view(for invoice: Invoice, settings: AppSettings) -> some View {
        IcelandicTemplate(invoice: invoice, settings: settings)
    }
}
