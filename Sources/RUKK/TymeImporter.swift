import Foundation

/// Tímafærsla úr Tyme-JSON útflutningi sem hægt er að breyta í reikningslínu.
struct TymeEntry: Identifiable {
    let id: String
    let note: String
    let task: String
    let project: String
    let durationMinutes: Int
    let rate: Decimal          // tímakaup
    let billing: String        // "UNBILLED" / "BILLED" / "PAID"
    let start: Date?

    /// Lengd í klukkustundum (t.d. 0,5).
    var hours: Decimal { Decimal(durationMinutes) / 60 }

    /// Lýsing fyrir reikningslínu: athugasemd, annars verkþáttur, annars verkefni.
    var lineDescription: String {
        let n = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty { return n }
        let t = task.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? project : t
    }

    var isUnbilled: Bool { billing.uppercased() == "UNBILLED" }
}

/// Les Tyme-JSON útflutning (`{"data":[…]}`) og skilar tímafærslum.
/// Tyme-snið: `note`, `duration` (mín., `duration_unit` "m"), `rate`, `sum`, `project`, `task`, `billing`.
enum TymeImporter {
    private struct Root: Decodable { let data: [Raw] }
    private struct Raw: Decodable {
        let id: String?
        let note: String?
        let task: String?
        let project: String?
        let duration: Int?
        let duration_unit: String?
        let rate: Decimal?
        let billing: String?
        let start: String?
    }

    static func parse(_ data: Data) -> [TymeEntry] {
        guard let root = try? JSONDecoder().decode(Root.self, from: data) else { return [] }
        let iso = ISO8601DateFormatter()
        return root.data.map { r in
            let minutes: Int = {
                let d = r.duration ?? 0
                switch (r.duration_unit ?? "m").lowercased() {
                case "h": return d * 60      // klukkustundir
                case "s": return d / 60      // sekúndur
                default:  return d           // "m" — mínútur (sjálfgefið)
                }
            }()
            return TymeEntry(id: r.id ?? UUID().uuidString,
                             note: r.note ?? "",
                             task: r.task ?? "",
                             project: r.project ?? "",
                             durationMinutes: minutes,
                             rate: r.rate ?? 0,
                             billing: r.billing ?? "",
                             start: r.start.flatMap { iso.date(from: $0) })
        }
        .sorted { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
    }
}
