import XCTest
@testable import RUKK

final class CustomerImportTests: XCTestCase {

    // Öll gögn hér eru tilbúin (gervigögn). Engin raunveruleg gögn viðskiptavina.

    // MARK: - Hjálp

    /// Skrifar innihald í tímabundna skrá með gefinni endingu og skilar slóð.
    private func tempFile(_ contents: String, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cust-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Hausakortlagning

    func testHeaderMappingIcelandic() {
        XCTAssertEqual(Field.string(forHeader: "Kennitala"), \CustomerRecord.nationalID)
        XCTAssertEqual(Field.string(forHeader: "Nafn"), \CustomerRecord.name)
        XCTAssertEqual(Field.string(forHeader: "Heimilisfang"), \CustomerRecord.address)
        XCTAssertEqual(Field.string(forHeader: "Póstnúmer"), \CustomerRecord.postalCode)
        XCTAssertEqual(Field.string(forHeader: "Staður"), \CustomerRecord.city)
        XCTAssertEqual(Field.string(forHeader: "Land"), \CustomerRecord.country)
        XCTAssertEqual(Field.string(forHeader: "Tengiliður"), \CustomerRecord.contactPerson)
        XCTAssertEqual(Field.string(forHeader: "Sími"), \CustomerRecord.phone)
        XCTAssertEqual(Field.string(forHeader: "Netfang"), \CustomerRecord.email)
        XCTAssertEqual(Field.string(forHeader: "Athugasemd"), \CustomerRecord.notes)
        // „Athugasemd" og „Sjálfgefin athugasemd á reikningum" mega ekki ruglast saman.
        XCTAssertEqual(Field.string(forHeader: "Sjálfgefin athugasemd á reikningum"), \CustomerRecord.defaultInvoiceNote)
        XCTAssertTrue(Field.isElectronicInvoiceHeader("Senda rafræna reikninga"))
        XCTAssertFalse(Field.isElectronicInvoiceHeader("Athugasemd"))
    }

    func testHeaderMappingEnglishAliases() {
        XCTAssertEqual(Field.string(forHeader: "National ID"), \CustomerRecord.nationalID)
        XCTAssertEqual(Field.string(forHeader: "Name"), \CustomerRecord.name)
        XCTAssertEqual(Field.string(forHeader: "E-mail"), \CustomerRecord.email)
        XCTAssertEqual(Field.string(forHeader: "Zip code"), \CustomerRecord.postalCode)
    }

    func testLooksLikeCompany() {
        XCTAssertTrue(CustomerImport.looksLikeCompany("Aðalatriði slf."))
        XCTAssertTrue(CustomerImport.looksLikeCompany("Blueberry Hills ehf."))
        XCTAssertTrue(CustomerImport.looksLikeCompany("Eitthvað hf"))
        XCTAssertTrue(CustomerImport.looksLikeCompany("Foo OHF."))
        XCTAssertTrue(CustomerImport.looksLikeCompany("Bar Ltd"))
        XCTAssertFalse(CustomerImport.looksLikeCompany("Arnar Lárus Baldursson"))
        XCTAssertFalse(CustomerImport.looksLikeCompany("Ágúst Gíslason"))
        XCTAssertFalse(CustomerImport.looksLikeCompany(""))
    }

    func testBoolParsing() {
        XCTAssertTrue(CustomerImport.parseBool("Já"))
        XCTAssertTrue(CustomerImport.parseBool("já"))
        XCTAssertTrue(CustomerImport.parseBool("yes"))
        XCTAssertTrue(CustomerImport.parseBool(" 1 "))
        XCTAssertFalse(CustomerImport.parseBool("Nei"))
        XCTAssertFalse(CustomerImport.parseBool(""))
    }

    // MARK: - CSV

    func testCSVSemicolonWithQuotedDelimiterAndBool() throws {
        let csv = """
        Kennitala;Nafn;Heimilisfang;Póstnúmer;Staður;Land;Tengiliður;Sími;Netfang;Athugasemd;Senda rafræna reikninga
        1234567890;Prófgögn ehf.;"Prófgata 1; 2. hæð";112;Reykjavík;Ísland;Nafn Nafnsson;;profgogn@example.is;;Já
        0987654321;Annar Aðili;Aðalstræti 2;400;Ísafjörður;Ísland;;5551234;annar@example.is;Nóta;Nei
        """
        let url = try tempFile(csv, ext: "csv")
        defer { try? FileManager.default.removeItem(at: url) }

        let records = try CustomerImport.records(from: url)
        XCTAssertEqual(records.count, 2)

        let a = records[0]
        XCTAssertEqual(a.nationalID, "1234567890")
        XCTAssertEqual(a.name, "Prófgögn ehf.")
        XCTAssertEqual(a.address, "Prófgata 1; 2. hæð")   // gæsalappir héldu aðgreini
        XCTAssertEqual(a.postalCode, "112")
        XCTAssertEqual(a.city, "Reykjavík")
        XCTAssertEqual(a.contactPerson, "Nafn Nafnsson")
        XCTAssertEqual(a.email, "profgogn@example.is")
        XCTAssertTrue(a.sendElectronicInvoices)

        let b = records[1]
        XCTAssertEqual(b.phone, "5551234")
        XCTAssertEqual(b.notes, "Nóta")
        XCTAssertFalse(b.sendElectronicInvoices)
    }

    func testCSVCommaWithEnglishHeaders() throws {
        let csv = """
        Name,National ID,Email,Phone,City,Country
        Acme Ltd,1122334455,info@acme.example,5551234,Reykjavik,Iceland
        """
        let url = try tempFile(csv, ext: "csv")
        defer { try? FileManager.default.removeItem(at: url) }

        let records = try CustomerImport.records(from: url)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].name, "Acme Ltd")
        XCTAssertEqual(records[0].nationalID, "1122334455")
        XCTAssertEqual(records[0].email, "info@acme.example")
        XCTAssertEqual(records[0].city, "Reykjavik")
        XCTAssertEqual(records[0].country, "Iceland")
    }

    func testCSVSkipsEmptyRows() throws {
        let csv = "Kennitala,Nafn,Netfang\n1234567890,Prófgögn ehf.,profgogn@example.is\n,,\n"
        let url = try tempFile(csv, ext: "csv")
        defer { try? FileManager.default.removeItem(at: url) }
        let records = try CustomerImport.records(from: url)
        XCTAssertEqual(records.count, 1)
    }

    // MARK: - XML

    func testXMLElementStyle() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <viðskiptavinir>
          <viðskiptavinur>
            <kennitala>1234567890</kennitala>
            <nafn>Prófgögn ehf.</nafn>
            <netfang>profgogn@example.is</netfang>
            <póstnúmer>112</póstnúmer>
            <staður>Reykjavík</staður>
            <rafraennReikningur>Já</rafraennReikningur>
          </viðskiptavinur>
          <viðskiptavinur>
            <kennitala>0987654321</kennitala>
            <nafn>Annar Aðili</nafn>
          </viðskiptavinur>
        </viðskiptavinir>
        """
        let url = try tempFile(xml, ext: "xml")
        defer { try? FileManager.default.removeItem(at: url) }

        let records = try CustomerImport.records(from: url)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0].name, "Prófgögn ehf.")
        XCTAssertEqual(records[0].nationalID, "1234567890")
        XCTAssertEqual(records[0].email, "profgogn@example.is")
        XCTAssertEqual(records[0].city, "Reykjavík")
        XCTAssertTrue(records[0].sendElectronicInvoices)
        XCTAssertEqual(records[1].name, "Annar Aðili")
        XCTAssertFalse(records[1].sendElectronicInvoices)
    }

    func testXMLAttributeStyle() throws {
        let xml = """
        <customers>
          <customer nationalID="1122334455" name="Acme Ltd" email="info@acme.example" city="Reykjavik"/>
        </customers>
        """
        let url = try tempFile(xml, ext: "xml")
        defer { try? FileManager.default.removeItem(at: url) }

        let records = try CustomerImport.records(from: url)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].name, "Acme Ltd")
        XCTAssertEqual(records[0].nationalID, "1122334455")
        XCTAssertEqual(records[0].email, "info@acme.example")
        XCTAssertEqual(records[0].city, "Reykjavik")
    }

    // MARK: - XLSX (tilbúið skjal — aðeins uppbygging, engir viðskiptavinir)

    private func fixtureURL() throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: "Vidskiptavinir", withExtension: "xlsx", subdirectory: "Fixtures"),
                      "Vantar fixture Vidskiptavinir.xlsx")
    }

    /// Sannreynir ZIP + DEFLATE + namespace-vinnslu: hausalínan á að lesast rétt.
    func testXLSXReaderParsesHeaderStructure() throws {
        let rows = try XLSXReader.rows(from: Data(contentsOf: fixtureURL()))
        XCTAssertEqual(rows.count, 1, "Fixture á aðeins að innihalda hausalínuna")
        let header = try XCTUnwrap(rows.first)
        XCTAssertEqual(header.count, 13)
        XCTAssertEqual(header.first, "Kennitala")
        XCTAssertTrue(header.contains("Netfang"))
        XCTAssertTrue(header.contains("Tengiliður"))
        XCTAssertTrue(header.contains("Senda rafræna reikninga"))
    }

    /// Allir 13 hausarnir í fixture eiga að kortleggjast á reit (eða rafræna-reikninga-fánann).
    func testXLSXFixtureHeadersAllRecognized() throws {
        let header = try XCTUnwrap(XLSXReader.rows(from: Data(contentsOf: fixtureURL())).first)
        for column in header {
            let recognized = Field.string(forHeader: column) != nil
                || Field.isElectronicInvoiceHeader(column)
            XCTAssertTrue(recognized, "Óþekktur haus: \(column)")
        }
    }

    /// Skrá með aðeins hausum inniheldur enga viðskiptavini → `.empty`.
    func testXLSXHeaderOnlyYieldsNoRecords() throws {
        XCTAssertThrowsError(try CustomerImport.records(from: fixtureURL())) { error in
            guard case CustomerImport.ImportError.empty = error else {
                return XCTFail("Bjóst við .empty, fékk \(error)")
            }
        }
    }
}
