import Foundation

/// Tamper-resistant record of the last time usage limits were loosened.
///
/// Kept out of SwiftData deliberately: deleting and reinstalling the app must
/// not hand back a fresh weekly allowance. Mirrors `EmergencyUnblockLedger`.
nonisolated protocol UsageLimitLedger: Sendable {
    func loadLastLoosened() -> Date?
    func saveLastLoosened(_ date: Date?)
}

struct KeychainUsageLimitLedger: UsageLimitLedger {
    private let item: KeychainItem

    init(
        service: String = "com.normalengineering.normal.usageLimits",
        account: String = "lastLoosened"
    ) {
        item = KeychainItem(service: service, account: account)
    }

    func loadLastLoosened() -> Date? {
        item.load(Double.self).map(Date.init(timeIntervalSinceReferenceDate:))
    }

    func saveLastLoosened(_ date: Date?) {
        guard let date else {
            item.delete()
            return
        }
        item.save(date.timeIntervalSinceReferenceDate)
    }
}

final class InMemoryUsageLimitLedger: UsageLimitLedger, @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date?

    init(date: Date? = nil) {
        self.date = date
    }

    func loadLastLoosened() -> Date? {
        lock.withLock { date }
    }

    func saveLastLoosened(_ date: Date?) {
        lock.withLock { self.date = date }
    }
}
