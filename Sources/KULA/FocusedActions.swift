import SwiftUI

// Aðgerðir sem virki gluggi birtir fyrir valmyndaskipanir (⌘N, ⌘P, útflutning).
// Skilgreint hér (í safninu) svo bæði view-in og App-skipanirnar sjái þær.

struct NewInvoiceAction: FocusedValueKey { typealias Value = () -> Void }
struct PrintInvoiceAction: FocusedValueKey { typealias Value = () -> Void }
struct ExportPDFAction: FocusedValueKey { typealias Value = () -> Void }
struct ExportXMLAction: FocusedValueKey { typealias Value = () -> Void }

extension FocusedValues {
    var newInvoice: (() -> Void)? {
        get { self[NewInvoiceAction.self] } set { self[NewInvoiceAction.self] = newValue }
    }
    var printInvoice: (() -> Void)? {
        get { self[PrintInvoiceAction.self] } set { self[PrintInvoiceAction.self] = newValue }
    }
    var exportPDF: (() -> Void)? {
        get { self[ExportPDFAction.self] } set { self[ExportPDFAction.self] = newValue }
    }
    var exportXML: (() -> Void)? {
        get { self[ExportXMLAction.self] } set { self[ExportXMLAction.self] = newValue }
    }
}
