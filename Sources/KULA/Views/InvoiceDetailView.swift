import SwiftUI
import SwiftData

struct InvoiceDetailView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var context
    @Query(sort: \Contact.name) private var contacts: [Contact]
    @Query(sort: \AppSettings.companyName) private var companies: [AppSettings]
    @AppStorage("activeCompanyID") private var activeCompanyID = ""

    @State private var isShowingPreview = true

    // Pure read: útgáfufyrirtæki reikningsins, annars virkt, annars transient.
    // Aldrei breytt í context meðan á view-teikningu stendur.
    private var settings: AppSettings {
        invoice.issuer
            ?? companies.first(where: { $0.id.uuidString == activeCompanyID })
            ?? companies.first
            ?? AppSettings()
    }

    /// Aðeins viðskiptavinir útgáfufyrirtækis reikningsins.
    private var companyContacts: [Contact] {
        let id = (invoice.issuer ?? settings).id
        return contacts.filter { $0.owner?.id == id }
    }

    var body: some View {
        HSplitView {
            form
                .frame(minWidth: 380, idealWidth: 460)

            if isShowingPreview {
                previewPane
                    .frame(minWidth: 480)
            }
        }
        .navigationTitle(invoice.number.isEmpty ? "Nýr reikningur" : invoice.number)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: $isShowingPreview) {
                    Label("Forskoðun", systemImage: "eye")
                }

                Button {
                    PDFRenderer.printInvoice(invoice: invoice, settings: settings)
                    invoice.printedAt = .now
                } label: {
                    Label("Prenta…", systemImage: "printer")
                }

                Menu {
                    Button("Senda í tölvupósti…") {
                        PDFRenderer.emailInvoice(invoice: invoice, settings: settings)
                        invoice.printedAt = .now
                    }
                    Button("Opna í Preview") {
                        PDFRenderer.openInPreview(invoice: invoice, settings: settings)
                    }
                    Button("Flytja út PDF…") {
                        PDFRenderer.export(invoice: invoice, settings: settings)
                        invoice.printedAt = .now
                    }
                    Button("Rafrænn reikningur (UBL / TS-136)…") {
                        UBLInvoiceExporter.export(invoice: invoice, company: settings)
                    }
                    Divider()
                    Button("Síðuuppsetning…") {
                        PDFRenderer.pageSetup()
                    }
                    if invoice.isPrinted {
                        Divider()
                        Button("Merkja sem óprentað") { invoice.printedAt = nil }
                    }
                } label: {
                    Label("Flytja út", systemImage: "square.and.arrow.up")
                }
            }
        }
        .focusedSceneValue(\.printInvoice) {
            PDFRenderer.printInvoice(invoice: invoice, settings: settings)
            invoice.printedAt = .now
        }
        .focusedSceneValue(\.exportPDF) {
            PDFRenderer.export(invoice: invoice, settings: settings)
            invoice.printedAt = .now
        }
        .focusedSceneValue(\.exportXML) {
            UBLInvoiceExporter.export(invoice: invoice, company: settings)
        }
    }

    private var form: some View {
        Form {
            Section("Reikningur") {
                TextField("Númer", text: $invoice.number)
                DatePicker("Útgáfudagur", selection: $invoice.issueDate, displayedComponents: .date)
                DatePicker("Gjalddagi",
                           selection: Binding(
                            get: { invoice.dueDate ?? invoice.issueDate },
                            set: { invoice.dueDate = $0 }),
                           displayedComponents: .date)
                Picker("Staða", selection: $invoice.status) {
                    ForEach(InvoiceStatus.allCases) { Text($0.label).tag($0) }
                }
                if invoice.status == .paid {
                    DatePicker("Greitt þann",
                               selection: Binding(
                                get: { invoice.paidAt ?? invoice.issueDate },
                                set: { invoice.paidAt = $0 }),
                               displayedComponents: .date)
                } else {
                    Button("Merkja sem greitt") { invoice.status = .paid }
                }
            }

            Section("Móttakandi") {
                Picker("Viðskiptavinur", selection: $invoice.recipient) {
                    Text("Enginn").tag(Optional<Contact>.none)
                    ForEach(companyContacts) { Text($0.name).tag(Optional($0)) }
                }
            }

            Section("Línur") {
                ForEach(invoice.orderedItems) { item in
                    LineItemRow(item: item)
                        .contextMenu {
                            Button("Afrita") {
                                let next = (invoice.lineItems.map(\.order).max() ?? -1) + 1
                                let copy = LineItem(description: item.itemDescription,
                                                    quantity: item.quantity,
                                                    unitPrice: item.unitPrice,
                                                    taxRate: item.taxRate,
                                                    order: next)
                                copy.invoice = invoice
                                invoice.lineItems.append(copy)
                                context.insert(copy)
                            }
                            Button("Færa upp", systemImage: "arrow.up") { move(item: item, by: -1) }
                            Button("Færa niður", systemImage: "arrow.down") { move(item: item, by: 1) }
                            Divider()
                            Button("Eyða", role: .destructive) { context.delete(item) }
                        }
                }
                .onDelete(perform: deleteItems)
                Button {
                    let next = (invoice.lineItems.map(\.order).max() ?? -1) + 1
                    let item = LineItem(taxRate: invoice.taxRate, order: next)
                    item.invoice = invoice
                    invoice.lineItems.append(item)
                    context.insert(item)
                } label: {
                    Label("Bæta við línu", systemImage: "plus")
                }
            }

            Section("Leiðréttingar") {
                HStack {
                    TextField("Afsláttur", value: $invoice.discountAmount, format: .number)
                    Toggle("%", isOn: $invoice.discountIsPercent).toggleStyle(.button)
                }
                HStack {
                    TextField("Sjálfgefið VSK% fyrir nýjar línur", value: $invoice.taxRate, format: .number)
                    Text("%")
                }
                TextField("Innh.máti", text: $invoice.collectionMethod)
                TextField("Mynt", text: $invoice.currencyCode)
            }

            Section("Athugasemd") {
                TextEditor(text: $invoice.note).frame(minHeight: 80)
            }

            Section("Samtölur") {
                LabeledContent("Undirsamtals", value: Money.format(invoice.subtotal, currencyCode: invoice.currencyCode))
                LabeledContent("Afsláttur", value: Money.format(invoice.discountValue, currencyCode: invoice.currencyCode))
                LabeledContent("VSK", value: Money.format(invoice.taxValue, currencyCode: invoice.currencyCode))
                LabeledContent("Samtals", value: Money.format(invoice.total, currencyCode: invoice.currencyCode))
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
    }

    private var previewPane: some View {
        ScrollView([.horizontal, .vertical]) {
            InvoiceRenderer.view(for: invoice, settings: settings)
                .border(Color(white: 0.85))
                .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = invoice.orderedItems
        for i in offsets { context.delete(items[i]) }
    }

    private func move(item: LineItem, by delta: Int) {
        let ordered = invoice.orderedItems
        guard let idx = ordered.firstIndex(of: item) else { return }
        let newIdx = idx + delta
        guard ordered.indices.contains(newIdx) else { return }
        let other = ordered[newIdx]
        let tmp = item.order
        item.order = other.order
        other.order = tmp
    }
}

private struct LineItemRow: View {
    @Bindable var item: LineItem

    var body: some View {
        HStack(spacing: 8) {
            TextField("Lýsing", text: $item.itemDescription)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
            TextField("Magn", value: $item.quantity, format: .number)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
            TextField("Verð", value: $item.unitPrice, format: .number)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            HStack(spacing: 2) {
                TextField("VSK", value: $item.taxRate, format: .number)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                Text("%").foregroundStyle(.secondary)
            }
            Text(Money.format(item.subtotalIncTax, currencyCode: item.invoice?.currencyCode ?? "ISK"))
                .monospacedDigit()
                .frame(width: 110, alignment: .trailing)
        }
    }
}
