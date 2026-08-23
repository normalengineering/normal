import Foundation

/// A proposed change to the usage limits, classified by direction.
///
/// Only *loosening* changes are rate limited — tightening is always immediate,
/// so the commitment device never stands between you and more discipline.
nonisolated enum UsageLimitEdit: Equatable, Sendable {
    case create(minutes: Int)
    /// `dropsCoverage` is true when apps were removed from what the limit
    /// meters — less watched is less restrictive, so it counts as loosening
    /// even if the allowance itself shrank.
    case adjust(from: Int, to: Int, dropsCoverage: Bool)
    case delete(minutes: Int)

    var isLoosening: Bool {
        switch self {
        case .create: false
        case let .adjust(from, to, dropsCoverage): to > from || dropsCoverage
        case .delete: true
        }
    }
}

/// Why a change was let through. Only `cooldownElapsed` starts a new week.
nonisolated enum UsageLimitEditAllowance: Equatable, Sendable {
    case tightening
    case grace
    case cooldownElapsed
}

nonisolated enum UsageLimitEditDecision: Equatable, Sendable {
    case allowed(UsageLimitEditAllowance)
    case locked(until: Date)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

/// What the Usage screen shows before any change is proposed.
nonisolated enum UsageLimitLockState: Equatable, Sendable {
    case unlocked
    case grace(until: Date)
    case locked(until: Date)

    var lockedUntil: Date? {
        if case let .locked(until) = self { return until }
        return nil
    }
}

/// Pure rules for when limits may be loosened.
///
/// The anchor is the moment of the last loosening and never moves during the
/// grace window — otherwise repeated edits inside grace would walk the clock
/// forward indefinitely and the weekly cooldown would never bite.
nonisolated enum UsageLimitEditPolicy {
    static let graceInterval: TimeInterval = .minutes(10)
    static let cooldownInterval: TimeInterval = .days(7)

    static func lockState(lastLoosenedAt: Date?, now: Date = .now) -> UsageLimitLockState {
        guard let anchor = lastLoosenedAt else { return .unlocked }
        let graceEnds = anchor + graceInterval
        if now < graceEnds { return .grace(until: graceEnds) }
        let unlock = anchor + cooldownInterval
        return now < unlock ? .locked(until: unlock) : .unlocked
    }

    static func decide(
        _ edit: UsageLimitEdit,
        lastLoosenedAt: Date?,
        now: Date = .now
    ) -> UsageLimitEditDecision {
        guard edit.isLoosening else { return .allowed(.tightening) }
        switch lockState(lastLoosenedAt: lastLoosenedAt, now: now) {
        case .unlocked: return .allowed(.cooldownElapsed)
        case .grace: return .allowed(.grace)
        case let .locked(until): return .locked(until: until)
        }
    }

    /// The anchor to persist after a change was applied.
    static func anchor(
        after allowance: UsageLimitEditAllowance,
        current: Date?,
        now: Date = .now
    ) -> Date? {
        allowance == .cooldownElapsed ? now : current
    }
}
