import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var context
    @Query private var contacts: [Contact]
    @Binding var selection: Contact?
    @State private var isImporting = false
    @State private var searchText = ""

    private let company: AppSettings

    init(company: AppSettings, selection: Binding<Contact?>) {
        self.company = company
        _selection = selection
        let cid = company.id
        _contacts = Query(filter: #Predicate<Contact> { $0.owner?.id == cid }, sort: \Contact.name)
    }

    private var filteredContacts: [Contact] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return contacts }
        return contacts.filter { c in
            [c.name, c.company, c.email, c.phone, c.nationalID]
                .contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredContacts) { contact in
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.name.isEmpty ? "(nafnlaus)" : contact.name).font(.headline)
                    if !contact.email.isEmpty {
                        Text(contact.email).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(contact)
                .contextMenu {
                    Button("Afrita") {
                        let copy = Contact(name: contact.name + " afrit",
                                           company: contact.company,
                                           nationalID: contact.nationalID,
                                           email: contact.email,
                                           phone: contact.phone,
                                           address: contact.address)
                        copy.notes = contact.notes
                        copy.owner = company
                        context.insert(copy)
                        selection = copy
                    }
                    Divider()
                    Button("Eyða", role: .destructive) {
                        if selection == contact { selection = nil }
                        context.delete(contact)
                    }
                }
            }
            .onDelete { offsets in
                let items = filteredContacts
                for i in offsets {
                    let contact = items[i]
                    if selection == contact { selection = nil }
                    context.delete(contact)
                }
            }
        }
        .searchable(text: $searchText, placement: .automatic, prompt: "Leita að viðskiptavini")
        .navigationTitle("Viðskiptavinir")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    isImporting = true
                } label: { Label("Flytja inn úr Tengiliðum", systemImage: "square.and.arrow.down") }

                Button {
                    let c = Contact(name: "Nýr viðskiptavinur")
                    c.owner = company
                    context.insert(c)
                    selection = c
                } label: { Label("Nýr viðskiptavinur", systemImage: "person.badge.plus") }
            }
        }
        .sheet(isPresented: $isImporting) {
            ContactImportView(company: company)
        }
    }
}
