import Foundation
import Compression

/// Léttur, pakka-laus lesari fyrir `.xlsx` (Office Open XML) skjöl.
///
/// `.xlsx` er ZIP-skjalasafn af XML-skrám. Hér er lesin fyrsta vinnusíðan og
/// skilað sem raðir af strengjum (fyrsta röð = hausar). Aðeins textagildi og
/// tölur eru studdar — það dugar fyrir innflutning viðskiptavina.
///
/// Engir SwiftPM-pakkar: ZIP-uppbygging er lesin handvirkt og `Compression`
/// (raw DEFLATE / `COMPRESSION_ZLIB`) sér um afþjöppun.
enum XLSXReader {

    enum ReadError: LocalizedError {
        case notAZip
        case noWorksheet
        case inflateFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAZip:          return String(localized: "Skráin er ekki gilt Excel-skjal.")
            case .noWorksheet:      return String(localized: "Engin vinnusíða fannst í Excel-skjalinu.")
            case .inflateFailed(let e): return "\(String(localized: "Gat ekki afþjappað Excel-skjalið:")) \(e)"
            }
        }
    }

    /// Les fyrstu vinnusíðuna og skilar röðum (fyrsta röð er venjulega hausalínan).
    static func rows(from data: Data) throws -> [[String]] {
        let bytes = [UInt8](data)
        let entries = try centralDirectory(bytes)

        // Deildar strengir (valkvætt).
        var shared: [String] = []
        if let ss = try inflatedEntry("xl/sharedStrings.xml", in: entries, bytes: bytes) {
            shared = parseSharedStrings(ss)
        }

        // Finna skrá fyrstu vinnusíðunnar (annars fyrsta sheetN.xml til vara).
        let sheetPath = worksheetPath(entries: entries, bytes: bytes)
        guard let sheetPath,
              let sheetData = try inflatedEntry(sheetPath, in: entries, bytes: bytes) else {
            throw ReadError.noWorksheet
        }
        return parseSheet(sheetData, shared: shared)
    }

    // MARK: - ZIP

    private struct Entry {
        let method: Int          // 0 = stored, 8 = deflate
        let compSize: Int
        let uncompSize: Int
        let localHeaderOffset: Int
    }

    /// Les miðlæga skrásafnið (central directory) og skilar færslum eftir nafni.
    private static func centralDirectory(_ b: [UInt8]) throws -> [String: Entry] {
        guard let eocd = findEOCD(b) else { throw ReadError.notAZip }
        let count = u16(b, eocd + 10)
        var offset = u32(b, eocd + 16)
        var result: [String: Entry] = [:]

        for _ in 0..<count {
            guard offset + 46 <= b.count, u32(b, offset) == 0x0201_4b50 else { break }
            let method   = u16(b, offset + 10)
            let compSize = u32(b, offset + 20)
            let uncomp   = u32(b, offset + 24)
            let fnLen    = u16(b, offset + 28)
            let extraLen = u16(b, offset + 30)
            let cmtLen   = u16(b, offset + 32)
            let localOff = u32(b, offset + 42)
            let nameStart = offset + 46
            let name = String(decoding: b[nameStart..<min(nameStart + fnLen, b.count)], as: UTF8.self)
            result[name] = Entry(method: method, compSize: compSize,
                                 uncompSize: uncomp, localHeaderOffset: localOff)
            offset = nameStart + fnLen + extraLen + cmtLen
        }
        guard !result.isEmpty else { throw ReadError.notAZip }
        return result
    }

    /// Leitar aftan frá að „End Of Central Directory“ undirskrift (0x06054b50).
    private static func findEOCD(_ b: [UInt8]) -> Int? {
        guard b.count >= 22 else { return nil }
        let minPos = max(0, b.count - 22 - 65_536)
        var i = b.count - 22
        while i >= minPos {
            if u32(b, i) == 0x0605_4b50 { return i }
            i -= 1
        }
        return nil
    }

    /// Afþjappar færslu í `[UInt8]` (nil ef hún er ekki til).
    private static func inflatedEntry(_ name: String, in entries: [String: Entry], bytes b: [UInt8]) throws -> [UInt8]? {
        guard let e = entries[name] else { return nil }
        // Lengd nafns/auka-svæðis í staðbundnum haus getur verið önnur en í skrásafninu.
        let lo = e.localHeaderOffset
        guard lo + 30 <= b.count, u32(b, lo) == 0x0403_4b50 else { throw ReadError.notAZip }
        let fnLen    = u16(b, lo + 26)
        let extraLen = u16(b, lo + 28)
        let dataStart = lo + 30 + fnLen + extraLen
        let dataEnd = dataStart + e.compSize
        guard dataEnd <= b.count else { throw ReadError.notAZip }
        let comp = Array(b[dataStart..<dataEnd])

        if e.method == 0 { return comp }                 // stored
        guard let out = inflate(comp, expectedSize: e.uncompSize) else {
            throw ReadError.inflateFailed(name)
        }
        return out
    }

    /// Raw DEFLATE afþjöppun með `Compression` (Apple `COMPRESSION_ZLIB` = RFC 1951, án zlib-hauss).
    private static func inflate(_ src: [UInt8], expectedSize: Int) -> [UInt8]? {
        if expectedSize == 0 { return [] }
        var dst = [UInt8](repeating: 0, count: expectedSize)
        let written = src.withUnsafeBufferPointer { sp in
            dst.withUnsafeMutableBufferPointer { dp in
                compression_decode_buffer(dp.baseAddress!, expectedSize,
                                          sp.baseAddress!, src.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        if written < expectedSize { dst.removeLast(expectedSize - written) }
        return dst
    }

    // MARK: - Little-endian les

    private static func u16(_ b: [UInt8], _ o: Int) -> Int {
        guard o + 1 < b.count else { return 0 }
        return Int(b[o]) | (Int(b[o + 1]) << 8)
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> Int {
        guard o + 3 < b.count else { return 0 }
        return Int(b[o]) | (Int(b[o + 1]) << 8) | (Int(b[o + 2]) << 16) | (Int(b[o + 3]) << 24)
    }

    // MARK: - Val á vinnusíðu

    /// Finnur skrá fyrstu vinnusíðunnar úr workbook + rels; annars fyrsta `sheetN.xml`.
    private static func worksheetPath(entries: [String: Entry], bytes b: [UInt8]) -> String? {
        if let wb = try? inflatedEntry("xl/workbook.xml", in: entries, bytes: b),
           let rels = try? inflatedEntry("xl/_rels/workbook.xml.rels", in: entries, bytes: b) {
            let wbXML = String(decoding: wb, as: UTF8.self)
            let relsXML = String(decoding: rels, as: UTF8.self)
            if let rid = firstMatch(in: wbXML, pattern: "<sheet[^>]*r:id=\"([^\"]+)\""),
               let relEl = firstMatch(in: relsXML, pattern: "<Relationship[^>]*Id=\"\(NSRegularExpression.escapedPattern(for: rid))\"[^>]*>"),
               let target = firstMatch(in: relEl, pattern: "Target=\"([^\"]+)\"") {
                let resolved = target.hasPrefix("/")
                    ? String(target.dropFirst())
                    : "xl/" + target.replacingOccurrences(of: "../", with: "")
                if entries[resolved] != nil { return resolved }
            }
        }
        // Til vara: fyrsta worksheet-skráin í stafrófsröð.
        return entries.keys
            .filter { $0.hasPrefix("xl/worksheets/") && $0.hasSuffix(".xml") }
            .sorted()
            .first
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range) else { return nil }
        let group = m.numberOfRanges > 1 ? m.range(at: 1) : m.range(at: 0)
        guard let r = Range(group, in: text) else { return nil }
        return String(text[r])
    }

    // MARK: - XML

    private static func parseSharedStrings(_ data: [UInt8]) -> [String] {
        let delegate = SharedStringsDelegate()
        let parser = XMLParser(data: Data(data))
        // Sum skjöl nota namespace-forskeyti (t.d. <x:si>); með namespace-vinnslu berast
        // local-nöfn ("si"/"t") óháð forskeyti.
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.strings
    }

    private static func parseSheet(_ data: [UInt8], shared: [String]) -> [[String]] {
        let delegate = SheetDelegate(shared: shared)
        let parser = XMLParser(data: Data(data))
        parser.shouldProcessNamespaces = true
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    /// Umbreytir dálk-tilvísun ("B7") í núll-vísaðan dálk-index (B → 1).
    fileprivate static func columnIndex(fromCellRef ref: String) -> Int {
        var idx = 0
        for ch in ref {
            guard let a = ch.asciiValue, a >= 65, a <= 90 else { break } // A–Z
            idx = idx * 26 + Int(a - 64)
        }
        return max(0, idx - 1)
    }
}

// MARK: - XMLParser delegates

private final class SharedStringsDelegate: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var capturing = false

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if name == "si" { current = "" }
        else if name == "t" { capturing = true }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { current += string }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "t" { capturing = false }
        else if name == "si" { strings.append(current); current = "" }
    }
}

private final class SheetDelegate: NSObject, XMLParserDelegate {
    var rows: [[String]] = []
    private let shared: [String]

    private var rowCells: [Int: String] = [:]
    private var maxCol = -1
    private var currentCol = 0
    private var cellType = ""          // t attribute ("s", "inlineStr", "str", "b", …)
    private var valueBuffer = ""
    private var capturingValue = false // inni í <v>
    private var capturingText = false  // inni í <t> (inlineStr)

    init(shared: [String]) { self.shared = shared }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        switch name {
        case "row":
            rowCells = [:]; maxCol = -1
        case "c":
            cellType = attributes["t"] ?? ""
            if let ref = attributes["r"] {
                currentCol = XLSXReader.columnIndex(fromCellRef: ref)
            } else {
                currentCol = maxCol + 1
            }
        case "v":
            valueBuffer = ""; capturingValue = true
        case "t":
            valueBuffer = capturingText ? valueBuffer : ""
            capturingText = true
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingValue || capturingText { valueBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "v":
            capturingValue = false
            let resolved: String
            if cellType == "s", let i = Int(valueBuffer), i >= 0, i < shared.count {
                resolved = shared[i]
            } else {
                resolved = valueBuffer
            }
            store(resolved)
        case "t":
            capturingText = false
            if cellType == "inlineStr" || cellType == "str" {
                store(valueBuffer)   // safnast upp fyrir marga <t>-búta
            }
        case "row":
            guard maxCol >= 0 else { rows.append([]); return }
            var arr = [String](repeating: "", count: maxCol + 1)
            for (c, v) in rowCells where c <= maxCol { arr[c] = v }
            rows.append(arr)
        default:
            break
        }
    }

    private func store(_ value: String) {
        rowCells[currentCol] = value
        if currentCol > maxCol { maxCol = currentCol }
    }
}
