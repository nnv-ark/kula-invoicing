import SwiftUI
import SwiftData
import os

let appLog = Logger(subsystem: "is.calmail.kula", category: "app")

@main
struct KULAApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self
            )
        } catch {
            // ModelContainer failure at launch is unrecoverable — the store is corrupt or
            // the schema is incompatible. Surface it via Logger before terminating.
            appLog.fault("Failed to create ModelContainer: \(error, privacy: .public)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("KÚLA") {
            ContentView()
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 760)
        .commands { KULACommands() }

        Settings {
            SettingsView()
                .modelContainer(container)
        }
        .defaultSize(width: 620, height: 520)
    }
}

// MARK: - Native valmyndaskipanir

struct KULACommands: Commands {
    @FocusedValue(\.newInvoice) private var newInvoice
    @FocusedValue(\.printInvoice) private var printInvoice
    @FocusedValue(\.exportPDF) private var exportPDF
    @FocusedValue(\.exportXML) private var exportXML

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nýr reikningur") { newInvoice?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(newInvoice == nil)
        }
        CommandGroup(replacing: .importExport) {
            Button("Flytja út PDF…") { exportPDF?() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(exportPDF == nil)
            Button("Flytja út rafrænan reikning (UBL / TS-136)…") { exportXML?() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportXML == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Prenta…") { printInvoice?() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(printInvoice == nil)
            Button("Síðuuppsetning…") { PDFRenderer.pageSetup() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
