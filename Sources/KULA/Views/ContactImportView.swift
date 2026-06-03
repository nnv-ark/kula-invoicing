import SwiftUI
import SwiftData
import Contacts
import AppKit

struct ContactImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let company: AppSettings

    @State private var contacts: [ImportedContact] = []
    @State private var selected: Set<UUID> = []
    @State private var phase: Phase = .loading

    private enum Phase { case loading, denied, ready, empty }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 480, height: 540)
        .task { await load() }
    }

    private var header: some View {
        HStack {
            Text("Flytja inn úr Tengiliðum").font(.headline)
            Spacer()
            if phase == .ready {
                Button(selected.count == contacts.count ? "Afvelja allt" : "Velja allt") {
                    selected = selected.count == contacts.count ? [] : Set(contacts.map(\.id))
                }
                .buttonStyle(.link)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView("Sæki tengiliði…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .denied:
            VStack(spacing: 12) {
                Image(systemName: "lock.circle").font(.largeTitle).foregroundStyle(.secondary)
                Text("KÚLA hefur ekki aðgang að Tengiliðum.")
                Button("Opna Persónuvernd í Kerfisstillingum") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        case .empty:
            ContentUnavailableView("Engir tengiliðir", systemImage: "person.crop.circle.badge.questionmark")
        case .ready:
            List {
                ForEach(contacts) { c in
                    Toggle(isOn: binding(for: c.id)) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.name.isEmpty ? c.company : c.name)
                            let sub = [c.company.isEmpty ? nil : c.company, c.email.isEmpty ? nil : c.email]
                                .compactMap { $0 }.joined(separator: " · ")
                            if !sub.isEmpty {
                                Text(sub).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Hætta við") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Flytja inn (\(selected.count))") { importSelected() }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
        }
        .padding(12)
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selected.contains(id) },
            set: { if $0 { selected.insert(id) } else { selected.remove(id) } }
        )
    }

    private func load() async {
        switch ContactImporter.authorizationStatus() {
        case .authorized:
            populate()
        case .notDetermined:
            if await ContactImporter.requestAccess() { populate() } else { phase = .denied }
        default:
            phase = .denied
        }
    }

    private func populate() {
        do {
            contacts = try ContactImporter.fetchAll()
            phase = contacts.isEmpty ? .empty : .ready
        } catch {
            phase = .denied
        }
    }

    private func importSelected() {
        for c in contacts where selected.contains(c.id) {
            let contact = Contact(name: c.name, company: c.company,
                                  email: c.email, phone: c.phone, address: c.address)
            contact.owner = company
            context.insert(contact)
        }
        dismiss()
    }
}
