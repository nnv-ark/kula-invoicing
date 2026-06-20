import XCTest
import SwiftData
@testable import RUKK

@MainActor
final class InvoiceMathTests: XCTestCase {

    /// Fresh in-memory store per test so relationships behave like production.
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @discardableResult
    private func addLine(_ invoice: Invoice, into context: ModelContext,
                         desc: String = "Lína", qty: Decimal, price: Decimal,
                         tax: Decimal, order: Int) -> LineItem {
        let item = LineItem(description: desc, quantity: qty, unitPrice: price, taxRate: tax, order: order)
        item.invoice = invoice
        invoice.lineItems.append(item)
        context.insert(item)
        return item
    }

    // MARK: - LineItem

    func testLineItemDerivedValues() throws {
        let item = LineItem(quantity: 3, unitPrice: 100, taxRate: 24)
        XCTAssertEqual(item.subtotal, 300)
        XCTAssertEqual(item.taxAmount, 72)            // 300 * 24%
        XCTAssertEqual(item.subtotalIncTax, 372)
        XCTAssertEqual(item.unitPriceIncTax, 124)     // 100 * 1.24
    }

    func testLineItemZeroTax() throws {
        let item = LineItem(quantity: 2, unitPrice: 50, taxRate: 0)
        XCTAssertEqual(item.subtotal, 100)
        XCTAssertEqual(item.taxAmount, 0)
        XCTAssertEqual(item.subtotalIncTax, 100)
    }

    // MARK: - Invoice totals

    func testInvoiceTotalsSingleLine() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "1", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)
        addLine(invoice, into: context, qty: 1, price: 50_000, tax: 0, order: 0)

        XCTAssertEqual(invoice.subtotal, 50_000)
        XCTAssertEqual(invoice.taxValue, 0)
        XCTAssertEqual(invoice.total, 50_000)
    }

    func testInvoiceTotalsMixedVatRates() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "2", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)
        addLine(invoice, into: context, qty: 1, price: 100_000, tax: 24, order: 0)
        addLine(invoice, into: context, qty: 2, price: 10_000, tax: 0, order: 1)

        XCTAssertEqual(invoice.subtotal, 120_000)          // 100k + 20k
        XCTAssertEqual(invoice.taxValue, 24_000)           // 24% of 100k, 0% of 20k
        XCTAssertEqual(invoice.total, 144_000)
    }

    // MARK: - Discount

    func testDiscountReducesVat() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "3", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)
        addLine(invoice, into: context, qty: 1, price: 1_000, tax: 24, order: 0)
        invoice.discountAmount = 20                         // 20%

        XCTAssertEqual(invoice.subtotal, 1_000)
        XCTAssertEqual(invoice.discountValue, 200)          // 20% of 1000
        XCTAssertEqual(invoice.taxableBase, 800)
        // VSK reiknast af afsláttargrunni: 24% af 800 = 192
        XCTAssertEqual(invoice.taxValue, 192)
        XCTAssertEqual(invoice.total, 992)                  // 800 + 192
    }

    func testPercentDiscount() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "4", currencyCode: "ISK", taxRate: 0)
        context.insert(invoice)
        addLine(invoice, into: context, qty: 1, price: 2_000, tax: 0, order: 0)
        invoice.discountAmount = 10                         // 10%

        XCTAssertEqual(invoice.discountValue, 200)         // 10% of 2000
        XCTAssertEqual(invoice.taxableBase, 1_800)
        XCTAssertEqual(invoice.total, 1_800)
    }

    // MARK: - VAT breakdown

    func testVatBreakdownGroupsAndSortsByRate() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "5", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)
        addLine(invoice, into: context, qty: 1, price: 100_000, tax: 24, order: 0)
        addLine(invoice, into: context, qty: 1, price: 50_000, tax: 24, order: 1)
        addLine(invoice, into: context, qty: 1, price: 20_000, tax: 0, order: 2)

        let breakdown = invoice.vatBreakdown
        XCTAssertEqual(breakdown.count, 2)

        // Sorted ascending by rate → 0% first, then 24%
        XCTAssertEqual(breakdown[0].rate, 0)
        XCTAssertEqual(breakdown[0].base, 20_000)
        XCTAssertEqual(breakdown[0].tax, 0)

        XCTAssertEqual(breakdown[1].rate, 24)
        XCTAssertEqual(breakdown[1].base, 150_000)         // 100k + 50k merged
        XCTAssertEqual(breakdown[1].tax, 36_000)           // 24% of 150k
    }

    func testEmptyInvoiceHasZeroTotals() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "6", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)

        XCTAssertEqual(invoice.subtotal, 0)
        XCTAssertEqual(invoice.taxValue, 0)
        XCTAssertEqual(invoice.total, 0)
        XCTAssertTrue(invoice.vatBreakdown.isEmpty)
    }

    // MARK: - Ordering

    func testOrderedItemsSortByOrderField() throws {
        let context = try makeContext()
        let invoice = Invoice(number: "7", currencyCode: "ISK", taxRate: 24)
        context.insert(invoice)
        addLine(invoice, into: context, desc: "C", qty: 1, price: 1, tax: 0, order: 2)
        addLine(invoice, into: context, desc: "A", qty: 1, price: 1, tax: 0, order: 0)
        addLine(invoice, into: context, desc: "B", qty: 1, price: 1, tax: 0, order: 1)

        XCTAssertEqual(invoice.orderedItems.map(\.itemDescription), ["A", "B", "C"])
    }
}
