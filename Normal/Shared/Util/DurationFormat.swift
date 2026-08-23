import Foundation

enum DurationFormat {
    /// "45m", "2h", "1h 30m" — the compact form used on schedule cards and
    /// usage limits.
    static func compact(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    /// "45 minutes", "2 hours", "1 hour, 30 minutes" — for body copy.
    ///
    /// Delegates pluralisation and locale ordering to Foundation rather than
    /// hand-assembling the string.
    static func spelled(minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .wide, zeroValueUnits: .hide)
        )
    }
}
