import SwiftUI
import SwiftData
import os

let appLog = Logger(subsystem: "is.calmail.kula", category: "app")

@main
struct KULAApp: App {
    let container: ModelContainer

    init() {
        do {
            #if DEBUG
            // Demó-ham keyrir á in-memory grunni svo sýnigögn snerti ekki raunveruleg gögn.
            let config = Demo.isActive ? ModelConfiguration(isStoredInMemoryOnly: true) : ModelConfiguration()
            container = try ModelContainer(
                for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self,
                configurations: config
            )
            #else
            container = try ModelContainer(
                for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self
            )
            #endif
        } catch {
            // ModelContainer failure at launch is unrecoverable — the store is corrupt or
            // the schema is incompatible. Surface it via Logger before terminating.
            appLog.fault("Failed to create ModelContainer: \(error, privacy: .public)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
        #if DEBUG
        if Demo.isActive {
            MainActor.assumeIsolated { Demo.seedIfNeeded(container.mainContext) }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup("KÚLA") {
            RootView()
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

// MARK: - Rótarsýn — áskriftargátt

/// Sýnir aðalviðmótið ef áskrift er virk, annars áskriftarskjáinn.
struct RootView: View {
    @State private var subscriptions = SubscriptionStore()

    private var forcePaywall: Bool {
        #if DEBUG
        return Demo.showPaywall
        #else
        return false
        #endif
    }

    private var unlocked: Bool {
        #if DEBUG
        if Demo.isActive { return true }
        #endif
        return subscriptions.isSubscribed
    }

    var body: some View {
        ZStack {
            if forcePaywall {
                PaywallView(store: subscriptions)
            } else if unlocked {
                ContentView()
            } else if subscriptions.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background)
            } else {
                PaywallView(store: subscriptions)
            }
        }
        .environment(subscriptions)
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
