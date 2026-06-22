import SwiftUI
import SwiftData
import EventKit

/// Sækir tímasetta atburði úr Dagatali og bætir völdum við reikninginn sem línur
/// (lýsing = titill, magn = klst., einingarverð = taxti).
struct CalendarImportView: View {
    @Bindable var invoice: Invoice
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
    @State private var toDate: Date = .now
    @State private var rate: Decimal = 0
    @State private var events: [BillableEvent] = []
    @State private var selected: Set<String> = []
    @State private var status: EKAuthorizationStatus = CalendarImporter.authorizationStatus()
    @State private var isLoading = false

    private var hasAccess: Bool { status == .fullAccess }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 540, height: 580)
        .task { await prepare() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sækja tíma úr dagatali").font(.headline)
            HStack(spacing: 16) {
                DatePicker("Frá", selection: $fromDate, displayedComponents: .date)
                DatePicker("Til", selection: $toDate, displayedComponents: .date)
            }
            HStack {
                Text("Taxti (kr/klst)")
                TextField("", value: $rate, format: .number)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                Spacer()
                Button("Sækja atburði") { Task { await load() } }
                    .disabled(!hasAccess || isLoading)
            }
        }
        .padding()
        .disabled(!hasAccess)
    }

    @ViewBuilder
    private var content: some View {
        if !hasAccess {
            permissionView
        } else if events.isEmpty {
            ContentUnavailableView("Engir atburðir",
                                   systemImage: "calendar",
                                   description: Text("Veldu tímabil og ýttu á „Sækja atburði“."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(events) { ev in
                    Toggle(isOn: binding(for: ev.id)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ev.title)
                            Text(subtitle(ev))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(status == .denied || status == .restricted
                 ? "RUKK hefur ekki aðgang að Dagatali."
                 : "Veittu aðgang að Dagatali til að sækja unninn tíma.")
                .multilineTextAlignment(.center)
            if status == .denied || status == .restricted {
                Button("Opna kerfisstillingar") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                Button("Veita aðgang") { Task { await requestAndLoad() } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var footer: some View {
        HStack {
            Button("Hætta við") { dismiss() }
            Spacer()
            Text(totalLabel).font(.caption).foregroundStyle(.secondary)
            Button("Bæta \(selected.count) við reikning") { addSelected(); dismiss() }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
        }
        .padding()
    }

    // MARK: - Logic

    private func prepare() async {
        if status == .notDetermined {
            await requestAndLoad()
        } else if hasAccess {
            await load()
        }
    }

    private func requestAndLoad() async {
        _ = await CalendarImporter.requestAccess()
        status = CalendarImporter.authorizationStatus()
        if hasAccess { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: toDate) ?? toDate
        events = CalendarImporter.events(from: fromDate, to: end)
        selected = []
    }

    private func addSelected() {
        let chosen = events.filter { selected.contains($0.id) }
        var order = (invoice.lineItems.map(\.order).max() ?? -1) + 1
        for ev in chosen {
            let li = LineItem(description: ev.title,
                              quantity: ev.hours,
                              unitPrice: rate,
                              taxRate: invoice.taxRate,
                              order: order)
            li.invoice = invoice
            invoice.lineItems.append(li)
            context.insert(li)
            order += 1
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(get: { selected.contains(id) },
                set: { if $0 { selected.insert(id) } else { selected.remove(id) } })
    }

    // MARK: - Formatting

    private func subtitle(_ ev: BillableEvent) -> String {
        let date = ev.start.formatted(date: .abbreviated, time: .shortened)
        var s = "\(date)  ·  \(hoursString(ev.hours)) klst"
        if !ev.calendarName.isEmpty { s += "  ·  \(ev.calendarName)" }
        return s
    }

    private var totalLabel: String {
        let total = events.filter { selected.contains($0.id) }.reduce(Decimal(0)) { $0 + $1.hours }
        return selected.isEmpty ? "" : "Samtals \(hoursString(total)) klst"
    }

    private func hoursString(_ h: Decimal) -> String {
        (h as NSDecimalNumber).doubleValue.formatted(.number.precision(.fractionLength(0...2)))
    }
}
