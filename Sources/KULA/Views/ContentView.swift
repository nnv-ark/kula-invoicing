import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case dashboard
    case invoices
    case contacts
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \AppSettings.companyName) private var companies: [AppSettings]
    @AppStorage("activeCompanyID") private var activeCompanyID = ""
    @AppStorage("kulaNormalizedV1") private var didNormalize = false
    @State private var selection: SidebarItem? = .dashboard
    @State private var selectedInvoice: Invoice?
    @State private var selectedContact: Contact?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Mælaborð", systemImage: "chart.bar.xaxis")
                    .tag(SidebarItem.dashboard)
                Section("Bókasafn") {
                    Label("Reikningar", systemImage: "doc.text")
                        .tag(SidebarItem.invoices)
                    Label("Viðskiptavinir", systemImage: "person.2")
                        .tag(SidebarItem.contacts)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    brandHeader
                    companySwitcher
                }
            }
        } content: {
            if let company = activeCompany {
                switch selection {
                case .dashboard:
                    dashboardBranding(company)
                case .invoices, .none:
                    InvoiceListView(company: company, selection: $selectedInvoice)
                        .id(company.id)               // ný fyrirspurn þegar skipt er um fyrirtæki
                case .contacts:
                    ContactsView(company: company, selection: $selectedContact)
                        .id(company.id)
                }
            } else {
                ProgressView()
            }
        } detail: {
            switch selection {
            case .dashboard:
                if let company = activeCompany {
                    DashboardView(company: company) { invoice in
                        selectedInvoice = invoice
                        selection = .invoices
                    }
                    .id(company.id)
                } else {
                    ProgressView()
                }
            case .contacts:
                if let contact = selectedContact {
                    CustomerDetailView(contact: contact) { invoice in
                        selectedInvoice = invoice
                        selection = .invoices
                    }
                } else {
                    ContentUnavailableView("Enginn viðskiptavinur valinn", systemImage: "person.2",
                                           description: Text("Veldu eða búðu til viðskiptavin."))
                }
            default:
                if let invoice = selectedInvoice {
                    InvoiceDetailView(invoice: invoice)
                } else {
                    ContentUnavailableView("Ekkert valið", systemImage: "doc.text",
                                           description: Text("Veldu eða búðu til reikning."))
                }
            }
        }
        .task {
            // Tryggja að a.m.k. eitt fyrirtæki sé til og að virkt fyrirtæki sé valið.
            let company = AppSettings.active(in: context, activeID: activeCompanyID)
            if activeCompanyID.isEmpty { activeCompanyID = company.id.uuidString }
            migrateOrphans(to: company)
            if !didNormalize {
                normalizeData()
                didNormalize = true
            }
        }
        .onChange(of: activeCompanyID) { _, _ in // Using two throwaway parameters to fix the deprecation warning
            selectedInvoice = nil   // gögn annars fyrirtækis eiga ekki að haldast valin
            selectedContact = nil
        }
        .focusedSceneValue(\.newInvoice, createInvoice)
    }

    /// Eldri gögn án fyrirtæris eru færð á virkt fyrirtæki svo þau hverfi ekki.
    private func migrateOrphans(to company: AppSettings) {
        if let invoices = try? context.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.issuer == nil })) {
            for inv in invoices { inv.issuer = company }
        }
        if let contacts = try? context.fetch(FetchDescriptor<Contact>(predicate: #Predicate { $0.owner == nil })) {
            for c in contacts { c.owner = company }
        }
    }

    /// Einskiptis-leiðrétting eldri gagna:
    /// 1) viðtakandi reiknings á alltaf að tilheyra útgáfufyrirtækinu (annars vantar hann í listann),
    /// 2) hvert fyrirtæki er endurnúmerað sjálfstætt 001, 002, … eftir stofndegi.
    private func normalizeData() {
        let allInvoices = (try? context.fetch(FetchDescriptor<Invoice>())) ?? []

        // 1) Tryggja að viðtakandi tilheyri sama fyrirtæki og reikningurinn.
        for inv in allInvoices {
            guard let issuer = inv.issuer, let rec = inv.recipient else { continue }
            if rec.owner?.id != issuer.id {
                let issuerID = issuer.id
                let owned = (try? context.fetch(FetchDescriptor<Contact>(
                    predicate: #Predicate { $0.owner?.id == issuerID }))) ?? []
                if let match = owned.first(where: { $0.name == rec.name && $0.nationalID == rec.nationalID }) {
                    inv.recipient = match
                } else {
                    let copy = Contact(name: rec.name, company: rec.company, nationalID: rec.nationalID,
                                       email: rec.email, phone: rec.phone, address: rec.address)
                    copy.owner = issuer
                    context.insert(copy)
                    inv.recipient = copy
                }
            }
        }

        // 2) Endurnúmera hvert fyrirtæki sjálfstætt.
        for company in AppSettings.all(in: context) {
            let cid = company.id
            let invs = (try? context.fetch(FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.issuer?.id == cid },
                sortBy: [SortDescriptor(\.createdAt)]))) ?? []
            for (i, inv) in invs.enumerated() {
                inv.number = Invoice.formattedNumber(prefix: company.invoiceNumberPrefix, i + 1)
            }
            company.nextInvoiceNumber = invs.count + 1
        }
    }

    private func createInvoice() {
        let company = AppSettings.active(in: context, activeID: activeCompanyID)
        let invoice = Invoice.makeNext(in: context, company: company)
        selection = .invoices
        selectedInvoice = invoice
    }

    private var activeCompany: AppSettings? {
        companies.first { $0.id.uuidString == activeCompanyID } ?? companies.first
    }

    /// Stórt fyrirtæktislógó í dálki 2 þegar mælaborð er valið
    /// (nafn fyrirtækis til vara ef ekkert lógó er sett).
    @ViewBuilder
    private func dashboardBranding(_ company: AppSettings) -> some View {
        VStack(spacing: 16) {
            Spacer()
            if let data = company.logoData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    // Aldrei stærra en lógóið á opnunarskjánum (96 px).
                    .frame(maxWidth: 96, maxHeight: 96)
                    .accessibilityLabel(Text(company.displayName))
            } else {
                Text(company.displayName.isEmpty ? "FYRIRTÆKI" : company.displayName)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    /// App-vörumerki efst í hliðarstiku — birtist aðeins einu sinni.
    private var brandHeader: some View {
        HStack(spacing: 8) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(Circle())
            Text("KÚLA")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    /// Native fyrirtækjaval efst í hliðarstiku — popup með haki á virku fyrirtæki.
    /// Lógóið er FYRIR UTAN Menu-ið; macOS Menu-merkimiði virðir ekki stærð á mynd.
    private var companySwitcher: some View {
        HStack(spacing: 10) {
            if let data = activeCompany?.logoData, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: "building.2.crop.circle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
            }
            Menu {
                Picker("Fyrirtæki", selection: $activeCompanyID) {
                    ForEach(companies) { c in
                        Text(c.displayName).tag(c.id.uuidString)
                    }
                }
                .pickerStyle(.inline)          // gefur haka á virku fyrirtæki
            } label: {
                HStack(spacing: 6) {
                    Text(activeCompany?.displayName ?? "Fyrirtæki")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self], inMemory: true)
}
