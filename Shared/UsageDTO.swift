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

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }
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
}

nonisolated struct UsageLimitConfig: Codable, Sendable, Equatable {
    var resetMinutes: Int
    var preventsAppDelete: Bool

    init(resetMinutes: Int = 0, preventsAppDelete: Bool = false) {
        self.resetMinutes = resetMinutes
        self.preventsAppDelete = preventsAppDelete
    }

    var period: UsagePeriod {
        UsagePeriod(resetMinutes: resetMinutes)
    }
}

nonisolated struct UsageDayStateDTO: Codable, Sendable, Equatable {
    private(set) var dayKey: String
    private(set) var states: [String: UsageLimitState]

    private var encodedExpiresAt: Date?
    private var encodedIsOverridden: Bool?

    var expiresAt: Date? {
        encodedExpiresAt
    }

    var isOverridden: Bool {
        encodedIsOverridden ?? false
    }

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

    static func fresh(on date: Date, period: UsagePeriod = UsagePeriod()) -> Self {
        UsageDayStateDTO(
            dayKey: period.key(for: date),
            states: [:],
            expiresAt: period.nextReset(after: date)
        )
    }

    func isStale(on date: Date, period: UsagePeriod = UsagePeriod()) -> Bool {
        guard dayKey != period.key(for: date) else { return false }
        guard let expiresAt else { return true }
        return date >= expiresAt
    }

    func state(for id: UUID, on date: Date, period: UsagePeriod = UsagePeriod()) -> UsageLimitState {
        guard !isStale(on: date, period: period) else { return .under }
        return states[id.uuidString] ?? .under
    }

    func recording(
        _ state: UsageLimitState,
        for id: UUID,
        on date: Date,
        period: UsagePeriod = UsagePeriod()
    ) -> Self {
        var updated = isStale(on: date, period: period) ? .fresh(on: date, period: period) : self
        guard state > (updated.states[id.uuidString] ?? .under) else { return updated }
        updated.states[id.uuidString] = state
        return updated
    }

    func clearing(_ id: UUID, on date: Date, period: UsagePeriod = UsagePeriod()) -> Self {
        guard !isStale(on: date, period: period) else { return self }
        var updated = self
        updated.states.removeValue(forKey: id.uuidString)
        return updated
    }

    func moving(from old: UsagePeriod, to new: UsagePeriod, on date: Date) -> Self {
        guard !isStale(on: date, period: old) else { return .fresh(on: date, period: new) }
        var updated = self
        updated.dayKey = new.key(for: date)
        updated.encodedExpiresAt = new.nextReset(after: date)
        return updated
    }

    func overriding(on date: Date, period: UsagePeriod = UsagePeriod()) -> Self {
        var updated = Self.fresh(on: date, period: period)
        updated.encodedIsOverridden = true
        return updated
    }
}

nonisolated struct UsagePeriod: Equatable, Sendable {
    let resetMinutes: Int
    let calendar: Calendar

    init(resetMinutes: Int = 0, calendar: Calendar = .current) {
        self.resetMinutes = min(max(resetMinutes, 0), 24 * 60 - 1)
        self.calendar = calendar
    }

    func start(containing date: Date) -> Date {
        let sameDay = reset(onDayOf: date)
        if sameDay <= date {
            return sameDay
        }
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) else { return sameDay }
        return reset(onDayOf: dayBefore)
    }

    func nextReset(after date: Date) -> Date {
        let sameDay = reset(onDayOf: date)
        if sameDay > date {
            return sameDay
        }
        guard let dayAfter = calendar.date(byAdding: .day, value: 1, to: date) else { return sameDay }
        return reset(onDayOf: dayAfter)
    }

    func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: start(containing: date))
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func couldHaveMetered(minutes: Int, by date: Date) -> Bool {
        let start = start(containing: date)
        let hourStart = calendar.dateInterval(of: .hour, for: start)?.start ?? start
        return date.timeIntervalSince(hourStart) + 60 >= TimeInterval(minutes) * 60
    }

    private func reset(onDayOf date: Date) -> Date {
        calendar.date(
            bySettingHour: resetMinutes / 60,
            minute: resetMinutes % 60,
            second: 0,
            of: date,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? calendar.startOfDay(for: date)
    }
}
