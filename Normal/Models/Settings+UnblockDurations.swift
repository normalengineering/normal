import Foundation

extension Settings {
    static let maxUnblockDurations = 8

    enum AddDurationResult: Equatable {
        case added
        case duplicate
        case limitReached
    }

    enum RemoveDurationResult: Equatable {
        case removed
        case removedDefault
        case lastRemaining
    }

    var unblockDurations: [TimedUnblockDuration] {
        TimedUnblockDuration.sanitized(customUnblockDurationSeconds)
    }

    var defaultDuration: TimedUnblockDuration? {
        get {
            guard let seconds = defaultUnblockSeconds ?? defaultUnblockDuration?.rawValue,
                  let duration = TimedUnblockDuration(validating: seconds),
                  unblockDurations.contains(duration)
            else { return nil }
            return duration
        }
        set {
            defaultUnblockSeconds = newValue?.seconds
            defaultUnblockDuration = nil
        }
    }

    func isDefault(_ duration: TimedUnblockDuration) -> Bool {
        defaultDuration == duration
    }

    @discardableResult
    func addUnblockDuration(_ duration: TimedUnblockDuration) -> AddDurationResult {
        let current = unblockDurations
        guard !current.contains(duration) else { return .duplicate }
        guard current.count < Self.maxUnblockDurations else { return .limitReached }
        customUnblockDurationSeconds = (current + [duration]).sorted().map(\.seconds)
        return .added
    }

    @discardableResult
    func removeUnblockDuration(_ duration: TimedUnblockDuration) -> RemoveDurationResult {
        let current = unblockDurations
        guard current.contains(duration) else { return .removed }
        guard current.count > 1 else { return .lastRemaining }
        let wasDefault = isDefault(duration)
        customUnblockDurationSeconds = current.filter { $0 != duration }.map(\.seconds)
        if wasDefault {
            defaultDuration = nil
        }
        return wasDefault ? .removedDefault : .removed
    }
}
