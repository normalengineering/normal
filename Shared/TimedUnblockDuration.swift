import Foundation

nonisolated struct TimedUnblockDuration: Hashable, Comparable, Identifiable, Sendable {
    let seconds: Int

    static let minimumSeconds = 15 * 60
    static let maximumSeconds = 23 * 3600 + 55 * 60
    static let stepSeconds = 5 * 60

    static let fifteenMinutes = TimedUnblockDuration(uncheckedSeconds: 900)
    static let thirtyMinutes = TimedUnblockDuration(uncheckedSeconds: 1800)
    static let oneHour = TimedUnblockDuration(uncheckedSeconds: 3600)
    static let fourHours = TimedUnblockDuration(uncheckedSeconds: 14400)

    static let presets: [TimedUnblockDuration] = [.fifteenMinutes, .thirtyMinutes, .oneHour, .fourHours]

    init?(validating seconds: Int) {
        guard Self.isValid(seconds) else { return nil }
        self.seconds = seconds
    }

    init?(hours: Int, minutes: Int) {
        self.init(validating: hours * 3600 + minutes * 60)
    }

    private init(uncheckedSeconds: Int) {
        seconds = uncheckedSeconds
    }

    static func isValid(_ seconds: Int) -> Bool {
        (minimumSeconds ... maximumSeconds).contains(seconds) && seconds % stepSeconds == 0
    }

    static func sanitized(_ seconds: [Int]?) -> [TimedUnblockDuration] {
        guard let seconds else { return presets }
        let valid = Set(seconds.compactMap(TimedUnblockDuration.init(validating:))).sorted()
        return valid.isEmpty ? presets : valid
    }

    var id: Int { seconds }

    var timeInterval: TimeInterval { TimeInterval(seconds) }

    var hours: Int { seconds / 3600 }

    var minutes: Int { seconds % 3600 / 60 }

    var label: String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .wide))
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.seconds < rhs.seconds }
}

nonisolated enum UnlockDurationRequest: Equatable, Sendable {
    case useDefault
    case ask
    case fixed(TimedUnblockDuration)

    static let askQueryValue = "ask"

    /// `nil` means the query item is omitted.
    var queryValue: String? {
        switch self {
        case .useDefault: nil
        case .ask: Self.askQueryValue
        case let .fixed(duration): String(duration.seconds)
        }
    }

    init(queryValue: String?) {
        guard let queryValue else {
            self = .useDefault
            return
        }
        if let seconds = Int(queryValue), String(seconds) == queryValue,
           let duration = TimedUnblockDuration(validating: seconds) {
            self = .fixed(duration)
        } else {
            self = .ask
        }
    }
}
