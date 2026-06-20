import Foundation
import SwiftData

@Model
final class Contact {
    var name: String = ""
    var company: String = ""
    var nationalID: String = ""            // kennitala / Viðskiptanúmer
    var email: String = ""
    var phone: String = ""
    var address: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    /// Fyrirtækið sem á þennan viðskiptavin (gögn aðskilin milli fyrirtækja).
    var owner: AppSettings?

    @Relationship(deleteRule: .nullify, inverse: \Invoice.recipient)
    var invoices: [Invoice] = []

    init(name: String = "", company: String = "", nationalID: String = "",
         email: String = "", phone: String = "", address: String = "") {
        self.name = name
        self.company = company
        self.nationalID = nationalID
        self.email = email
        self.phone = phone
        self.address = address
        self.createdAt = .now
    }
}
