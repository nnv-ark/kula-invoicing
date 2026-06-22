import Foundation
import EventKit
import os

private let calLog = Logger(subsystem: "is.calmail.kula", category: "calendar")

/// Léttur framsetningarhlutur fyrir dagatalsatburð sem hægt er að rukka fyrir.
struct BillableEvent: Identifiable {
    let id: String
    let title: String
    let calendarName: String
    let start: Date
    let end: Date

    /// Lengd atburðar í klukkustundum (t.d. 1,5).
    var hours: Decimal {
        let minutes = max(0, end.timeIntervalSince(start)) / 60
        return Decimal(minutes) / 60
    }
}

/// Les atburði úr Dagatali (EventKit) til að breyta í reikningslínur.
/// Krefst `com.apple.security.personal-information.calendars` + NSCalendarsFullAccessUsageDescription.
@MainActor
enum CalendarImporter {
    static let store = EKEventStore()

    static func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Biður um fullan aðgang að atburðum (macOS 14+).
    static func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            calLog.error("Calendar access error: \(error, privacy: .public)")
            return false
        }
    }

    /// Tímasettir atburðir á tímabili (úr öllum dagatölum), raðaðir eftir upphafstíma.
    /// Heilsdagsatburðir eru sleppt — þeir hafa enga rukkanlega lengd.
    static func events(from start: Date, to end: Date) -> [BillableEvent] {
        guard end > start else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
            .map { ev in
                BillableEvent(id: ev.eventIdentifier ?? UUID().uuidString,
                              title: (ev.title?.isEmpty == false) ? ev.title! : "Atburður",
                              calendarName: ev.calendar?.title ?? "",
                              start: ev.startDate ?? .now,
                              end: ev.endDate ?? ev.startDate ?? .now)
            }
    }
}
