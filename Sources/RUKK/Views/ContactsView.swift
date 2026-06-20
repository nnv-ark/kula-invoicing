import SwiftUI
import SwiftData

struct ContactsView: View {
    @Environment(\.modelContext) private var context
    @Query private var contacts: [Contact]
    @Binding var selection: Contact?
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
        .navigationTitle("Viðskiptavinir")
        // „Nýr viðskiptavinur" og leit efst í dálki 2.
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Button(action: newCustomer) {
                        Label("Nýr viðskiptavinur", systemImage: "person.badge.plus")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    .fixedSize()
                    .help("Nýr viðskiptavinur")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 7)
                .padding(.bottom, 6)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Leita að viðskiptavini", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 7)

                Divider()
            }
            .background(.bar)
        }
    }

    private func newCustomer() {
        let c = Contact(name: "Nýr viðskiptavinur")
        c.owner = company
        context.insert(c)
        selection = c
    }
}
