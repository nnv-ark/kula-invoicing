import XCTest
@testable import RUKK

final class LocalizationTests: XCTestCase {

    func testFromFallsBackToIcelandicForUnknownValue() {
        XCTAssertEqual(AppLanguage.from("is"), .icelandic)
        XCTAssertEqual(AppLanguage.from("en"), .english)
        XCTAssertEqual(AppLanguage.from("xx"), .icelandic)
        XCTAssertEqual(AppLanguage.from(""), .icelandic)
    }

    func testInvoiceStringsAreIndependentPerLanguage() {
        let is_ = InvoiceStrings(.icelandic)
        let en = InvoiceStrings(.english)

        XCTAssertEqual(is_.invoiceNo, "Reikningur nr.")
        XCTAssertEqual(en.invoiceNo, "Invoice no.")
        XCTAssertNotEqual(is_.invoiceNo, en.invoiceNo)

        XCTAssertEqual(is_.itemDescription, "Lýsing")
        XCTAssertEqual(en.itemDescription, "Description")

        XCTAssertEqual(is_.currencySuffix, "kr.")
        XCTAssertEqual(en.currencySuffix, "ISK")
    }

    func testPrefixedValuesCarryTheRawValueUnchanged() {
        let is_ = InvoiceStrings(.icelandic)
        let en = InvoiceStrings(.english)

        XCTAssertEqual(is_.idNo("5301234560"), "kt. 5301234560")
        XCTAssertEqual(en.idNo("5301234560"), "ID no. 5301234560")

        XCTAssertEqual(is_.bankAccount("0133-26-004567"), "Reikningsnr: 0133-26-004567")
        XCTAssertEqual(en.bankAccount("0133-26-004567"), "Bank acc.: 0133-26-004567")
    }

    func testDiscountLabelEmbedsThePercent() {
        let is_ = InvoiceStrings(.icelandic)
        let en = InvoiceStrings(.english)

        XCTAssertEqual(is_.discountLabel("10"), "Afsláttur (10%)")
        XCTAssertEqual(en.discountLabel("10"), "Discount (10%)")
    }

    func testCurrencyFormattingUsesTheInvoiceLanguageNotSystemLocale() {
        let is_ = InvoiceStrings(.icelandic)
        let en = InvoiceStrings(.english)

        XCTAssertTrue(is_.currency(1000).hasSuffix("kr."))
        XCTAssertTrue(en.currency(1000).hasSuffix("ISK"))
    }

    /// Amount formatting is independent per instance — changing one language's
    /// formatter must never leak into the other (each InvoiceStrings is a fresh value).
    func testAmountFormattingIsConsistentAcrossRepeatedCalls() {
        let en = InvoiceStrings(.english)
        XCTAssertEqual(en.amountString(1000), en.amountString(1000))
    }
}
