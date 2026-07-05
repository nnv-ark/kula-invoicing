import Foundation
import SwiftData

@Model
final class Contact {
    var name: String = ""
    var company: String = ""
    var nationalID: String = ""            // kennitala / Viðskiptanúmer
    var email: String = ""
    var phone: String = ""
    var address: String = ""               // Heimilisfang (gata)
    var postalCode: String = ""            // Póstnúmer
    var city: String = ""                  // Staður
    var country: String = ""               // Land
    var contactPerson: String = ""         // Tengiliður
    var extraInfo: String = ""             // Aukaupplýsingar
    var notes: String = ""                 // Athugasemd
    var defaultInvoiceNote: String = ""    // Sjálfgefin athugasemd á reikningum
    var sendElectronicInvoices: Bool = false // Senda rafræna reikninga
    var createdAt: Date = Date()

    /// Fyrirtækið sem á þennan viðskiptavin (gögn aðskilin milli fyrirtækja).
    var owner: AppSettings?

    @Relationship(deleteRule: .nullify, inverse: \Invoice.recipient)
    var invoices: [Invoice] = []

    init(name: String = "", company: String = "", nationalID: String = "",
         email: String = "", phone: String = "", address: String = "",
         postalCode: String = "", city: String = "", country: String = "",
         contactPerson: String = "", extraInfo: String = "",
         defaultInvoiceNote: String = "", sendElectronicInvoices: Bool = false) {
        self.name = name
        self.company = company
        self.nationalID = nationalID
        self.email = email
        self.phone = phone
        self.address = address
        self.postalCode = postalCode
        self.city = city
        self.country = country
        self.contactPerson = contactPerson
        self.extraInfo = extraInfo
        self.defaultInvoiceNote = defaultInvoiceNote
        self.sendElectronicInvoices = sendElectronicInvoices
        self.createdAt = .now
    }
}
