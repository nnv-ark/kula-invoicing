import SwiftUI

enum InvoiceStatus: String, CaseIterable, Codable, Identifiable {
    case draft
    case sent
    case paid
    case overdue
    case refunded
    case cancelled

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .draft: "Drög"
        case .sent: "Sent"
        case .paid: "Greitt"
        case .overdue: "Á eftir"
        case .refunded: "Endurgreitt"
        case .cancelled: "Hætt við"
        }
    }
}
