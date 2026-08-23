import Foundation

/// Lifecycle of a single daily usage limit within one day.
///
/// Advanced only by `NormalMonitor` in response to `DeviceActivity` threshold
/// callbacks, and reset when the day rolls over.
nonisolated enum UsageLimitState: String, Codable, Sendable, CaseIterable, Comparable {
    case under
    case warning
    case reached

    /// Severity order. States only ever advance within a day, so a late
    /// `warning` callback cannot undo a `reached` one.
    private var rank: Int {
        switch self {
        case .under: 0
        case .warning: 1
        case .reached: 2
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// A daily usage limit, flattened for the monitor extension.
///
/// Fields added after v1 should follow the `encoded…` convention used by the
/// other shared DTOs — optional storage with a defaulting accessor — so a
/// payload written by an older build still decodes instead of throwing and
/// taking every limit down with it.
nonisolated struct UsageLimitDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let selectionData: Data
    let minutesPerDay: Int

    init(id: UUID, selectionData: Data, minutesPerDay: Int) {
        self.id = id
        self.selectionData = selectionData
        self.minutesPerDay = minutesPerDay
    }
}

/// Per-day limit states, plus the two facts that decide whether the record is
/// still in force: when the day it belongs to actually ends, and whether an
/// emergency unblock has overridden limits for that day.
nonisolated struct UsageDayStateDTO: Codable, Sendable, Equatable {
    private(set) var dayKey: String
    private(set) var states: [String: UsageLimitState]

    private var encodedExpiresAt: Date?
    private var encodedIsOverridden: Bool?

    /// Absolute instant this day's record stops applying.
    ///
    /// Stored as a real `Date` rather than re-derived from `dayKey`, so moving
    /// the device clock backwards cannot retire a spent allowance early.
    var expiresAt: Date? { encodedExpiresAt }

    /// An emergency unblock outranked the caps for this day.
    var isOverridden: Bool { encodedIsOverridden ?? false }

    static let empty = UsageDayStateDTO(dayKey: "", states: [:])

    init(
        dayKey: String,
        states: [String: UsageLimitState],
        expiresAt: Date? = nil,
        isOverridden: Bool? = nil
    ) {
        self.dayKey = dayKey
        self.states = states
        encodedExpiresAt = expiresAt
        encodedIsOverridden = isOverridden
    }

    static func fresh(on date: Date, calendar: Calendar = .current) -> Self {
        UsageDayStateDTO(
            dayKey: UsageDayKey.key(for: date, calendar: calendar),
            states: [:],
            expiresAt: UsageDayKey.nextReset(after: date, calendar: calendar)
        )
    }

    /// A record is spent only once the calendar day has changed *and* the
    /// absolute reset instant has actually passed. Requiring both means a
    /// rolled-back clock or a westward flight cannot refund the day.
    func isStale(on date: Date, calendar: Calendar = .current) -> Bool {
        guard dayKey != UsageDayKey.key(for: date, calendar: calendar) else { return false }
        guard let expiresAt else { return true }
        return date >= expiresAt
    }

    func state(for id: UUID, on date: Date, calendar: Calendar = .current) -> UsageLimitState {
        guard !isStale(on: date, calendar: calendar) else { return .under }
        return states[id.uuidString] ?? .under
    }

    /// Advances one limit's state, rolling the whole record over first if it
    /// belongs to a day that has ended. Never downgrades within a day.
    func recording(
        _ state: UsageLimitState,
        for id: UUID,
        on date: Date,
        calendar: Calendar = .current
    ) -> Self {
        var updated = isStale(on: date, calendar: calendar) ? .fresh(on: date, calendar: calendar) : self
        guard state > (updated.states[id.uuidString] ?? .under) else { return updated }
        updated.states[id.uuidString] = state
        return updated
    }

    /// Drops one limit's record, so a raised ceiling takes effect immediately
    /// instead of waiting for the reset. A no-op against a day already spent.
    func clearing(_ id: UUID, on date: Date, calendar: Calendar = .current) -> Self {
        guard !isStale(on: date, calendar: calendar) else { return self }
        var updated = self
        updated.states.removeValue(forKey: id.uuidString)
        return updated
    }

    func overriding(on date: Date, calendar: Calendar = .current) -> Self {
        var updated = Self.fresh(on: date, calendar: calendar)
        updated.encodedIsOverridden = true
        return updated
    }
}

/// Local-calendar day identity, cheap enough for the memory-constrained
/// monitor extension (no `DateFormatter`).
nonisolated enum UsageDayKey {
    static func key(for date: Date = .now, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Start of the next local day.
    ///
    /// Uses start-of-day arithmetic rather than matching midnight components,
    /// so zones whose DST transition happens at midnight — where 00:00 does not
    /// exist — still resolve to the real first instant of the day.
    static func nextReset(after date: Date = .now, calendar: Calendar = .current) -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        else { return date }
        return calendar.startOfDay(for: tomorrow)
    }
}
