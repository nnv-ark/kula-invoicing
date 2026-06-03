import XCTest
import SwiftData
@testable import KULA

@MainActor
final class UBLExportTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func sampleInvoice(_ context: ModelContext) -> (Invoice, AppSettings) {
        let company = AppSettings()
        company.companyName = "NNV ehf."
        company.companyNationalID = "4702221580"
        company.companyVATNumber = "143820"
        company.bankAccountNumber = "0133-26-005422"
        company.companyEmail = "oli@nordnordvestur.com"
        context.insert(company)

        let contact = Contact(name: "Jón", company: "koa arkitektar ehf.",
                              nationalID: "6504220660", address: "Hnífsdalsvegi 10")
        context.insert(contact)

        let invoice = Invoice(number: "0000087", currencyCode: "ISK", taxRate: 24)
        invoice.issuer = company
        invoice.recipient = contact
        context.insert(invoice)

        let l1 = LineItem(description: "Hönnun", quantity: 1, unitPrice: 100_000, taxRate: 24, order: 0)
        l1.invoice = invoice; invoice.lineItems.append(l1); context.insert(l1)
        let l2 = LineItem(description: "kostnaður", quantity: 2, unitPrice: 10_000, taxRate: 0, order: 1)
        l2.invoice = invoice; invoice.lineItems.append(l2); context.insert(l2)

        return (invoice, company)
    }

    func testXMLContainsCoreElements() throws {
        let context = try makeContext()
        let (invoice, company) = sampleInvoice(context)
        let xml = UBLInvoiceExporter.xml(for: invoice, company: company)

        XCTAssertTrue(xml.hasPrefix("<?xml"))
        XCTAssertTrue(xml.contains("<Invoice"))
        XCTAssertTrue(xml.contains("urn:cen.eu:en16931:2017#compliant#urn:fdc:peppol.eu:2017:poacc:billing:3.0"))
        XCTAssertTrue(xml.contains("<cbc:ID>0000087</cbc:ID>"))
        XCTAssertTrue(xml.contains("<cbc:DocumentCurrencyCode>ISK</cbc:DocumentCurrencyCode>"))
        XCTAssertTrue(xml.contains("NNV ehf."))
        XCTAssertTrue(xml.contains("koa arkitektar ehf."))
        XCTAssertTrue(xml.contains(#"schemeID="0196""#))
    }

    func testMonetaryTotalsReconcile() throws {
        let context = try makeContext()
        let (invoice, company) = sampleInvoice(context)
        let xml = UBLInvoiceExporter.xml(for: invoice, company: company)

        // subtotal 120000, tax 24000 (24% of 100k), total 144000
        XCTAssertTrue(xml.contains("<cbc:LineExtensionAmount currencyID=\"ISK\">120000.00</cbc:LineExtensionAmount>"))
        XCTAssertTrue(xml.contains("<cbc:TaxInclusiveAmount currencyID=\"ISK\">144000.00</cbc:TaxInclusiveAmount>"))
        XCTAssertTrue(xml.contains("<cbc:PayableAmount currencyID=\"ISK\">144000.00</cbc:PayableAmount>"))
        XCTAssertTrue(xml.contains("<cbc:TaxAmount currencyID=\"ISK\">24000.00</cbc:TaxAmount>"))
    }

    func testTwoTaxSubtotalsForMixedRates() throws {
        let context = try makeContext()
        let (invoice, company) = sampleInvoice(context)
        let xml = UBLInvoiceExporter.xml(for: invoice, company: company)

        let subtotals = xml.components(separatedBy: "<cac:TaxSubtotal>").count - 1
        XCTAssertEqual(subtotals, 2, "Expected one TaxSubtotal per VAT rate (0% and 24%)")
        XCTAssertTrue(xml.contains("<cbc:ID>S</cbc:ID>"))
        XCTAssertTrue(xml.contains("<cbc:ID>Z</cbc:ID>"))
    }

    func testTwoInvoiceLines() throws {
        let context = try makeContext()
        let (invoice, company) = sampleInvoice(context)
        let xml = UBLInvoiceExporter.xml(for: invoice, company: company)
        let lines = xml.components(separatedBy: "<cac:InvoiceLine>").count - 1
        XCTAssertEqual(lines, 2)
    }

    func testXMLEscaping() throws {
        let context = try makeContext()
        let (invoice, company) = sampleInvoice(context)
        invoice.orderedItems[0].itemDescription = "Ráðgjöf & hönnun <A>"
        let xml = UBLInvoiceExporter.xml(for: invoice, company: company)
        XCTAssertTrue(xml.contains("Ráðgjöf &amp; hönnun &lt;A&gt;"))
        XCTAssertFalse(xml.contains("hönnun <A>"))
    }
}
