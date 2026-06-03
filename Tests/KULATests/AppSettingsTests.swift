import XCTest
import SwiftData
@testable import KULA

@MainActor
final class AppSettingsTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Invoice.self, LineItem.self, Contact.self, AppSettings.self, CustomStatus.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func count(in context: ModelContext) throws -> Int {
        try context.fetch(FetchDescriptor<AppSettings>()).count
    }

    func testActiveSeedsOneCompanyWhenEmpty() throws {
        let context = try makeContext()
        XCTAssertEqual(try count(in: context), 0)

        _ = AppSettings.active(in: context, activeID: "")

        XCTAssertEqual(try count(in: context), 1)
    }

    func testActiveReusesWhenNoIDGiven() throws {
        let context = try makeContext()

        let a = AppSettings.active(in: context, activeID: "")
        let b = AppSettings.active(in: context, activeID: "")

        XCTAssertEqual(try count(in: context), 1, "Empty ID must reuse the first company, not create more")
        XCTAssertTrue(a === b)
    }

    func testActiveMatchesByID() throws {
        let context = try makeContext()
        let first = AppSettings()
        first.companyName = "Fyrsta"
        let second = AppSettings()
        second.companyName = "Annað"
        context.insert(first)
        context.insert(second)

        let resolved = AppSettings.active(in: context, activeID: second.id.uuidString)

        XCTAssertTrue(resolved === second)
        XCTAssertEqual(try count(in: context), 2, "Resolving must not create extra rows")
    }

    func testActiveFallsBackToFirstForUnknownID() throws {
        let context = try makeContext()
        let only = AppSettings()
        only.companyName = "Eina"
        context.insert(only)

        let resolved = AppSettings.active(in: context, activeID: UUID().uuidString)

        XCTAssertTrue(resolved === only)
        XCTAssertEqual(try count(in: context), 1)
    }

    func testAllReturnsEverySortedByName() throws {
        let context = try makeContext()
        for name in ["Gamma", "Alfa", "Beta"] {
            let c = AppSettings(); c.companyName = name; context.insert(c)
        }

        let names = AppSettings.all(in: context).map(\.companyName)
        XCTAssertEqual(names, ["Alfa", "Beta", "Gamma"])
    }

    func testDisplayNameFallback() throws {
        let c = AppSettings()
        XCTAssertEqual(c.displayName, "Ónefnt fyrirtæki")
        c.fullName = "Óli"
        XCTAssertEqual(c.displayName, "Óli")
        c.companyName = "NNV ehf."
        XCTAssertEqual(c.displayName, "NNV ehf.")
    }
}
