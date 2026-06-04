import Foundation

final class InMemoryEmergencyUnblockLedger: EmergencyUnblockLedger, @unchecked Sendable {
    private let lock = NSLock()
    private var dates: [Date]

    init(dates: [Date] = []) {
        self.dates = dates
    }

    func load() -> [Date] {
        lock.withLock { dates }
    }

    func save(_ dates: [Date]) {
        lock.withLock { self.dates = dates }
    }
}
