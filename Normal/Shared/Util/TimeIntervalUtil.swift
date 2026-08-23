import Foundation

/// Pure arithmetic, so explicitly nonisolated — the project defaults to
/// `MainActor` isolation, which would otherwise put these out of reach of
/// nonisolated types like `UsageLimitEditPolicy`.
nonisolated extension TimeInterval {
    static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * 86400 }
    static func hours(_ count: Int) -> TimeInterval { TimeInterval(count) * 3600 }
    static func minutes(_ count: Int) -> TimeInterval { TimeInterval(count) * 60 }
}
