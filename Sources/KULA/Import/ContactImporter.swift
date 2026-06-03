import Foundation
import Contacts
import os

private let importLog = Logger(subsystem: "is.calmail.kula", category: "contacts")

/// Léttur framsetningarhlutur fyrir tengilið úr Contacts.app.
struct ImportedContact: Identifiable {
    let id = UUID()
    var name: String
    var company: String
    var email: String
    var phone: String
    var address: String
}

/// Les tengiliði úr Contacts.app (kerfisleyfi krafist).
enum ContactImporter {
    static func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    static func requestAccess() async -> Bool {
        await withCheckedContinuation { cont in
            CNContactStore().requestAccess(for: .contacts) { granted, error in
                if let error { importLog.error("Contacts access error: \(error, privacy: .public)") }
                cont.resume(returning: granted)
            }
        }
    }

    static func fetchAll() throws -> [ImportedContact] {
        let store = CNContactStore()
        let keys = [
            CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey,
            CNContactEmailAddressesKey, CNContactPhoneNumbersKey, CNContactPostalAddressesKey
        ] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)

        var result: [ImportedContact] = []
        try store.enumerateContacts(with: request) { c, _ in
            let fullName = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            let display = fullName.isEmpty ? c.organizationName : fullName
            let email = c.emailAddresses.first.map { $0.value as String } ?? ""
            let phone = c.phoneNumbers.first?.value.stringValue ?? ""
            let address = c.postalAddresses.first.map {
                CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)
                    .replacingOccurrences(of: "\n", with: ", ")
            } ?? ""
            guard !(display.isEmpty && email.isEmpty) else { return }
            result.append(ImportedContact(name: display, company: c.organizationName,
                                          email: email, phone: phone, address: address))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
