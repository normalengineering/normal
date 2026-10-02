import Foundation
import ManagedSettings

protocol DailyLimitShielding: AnyObject {
    func apply(_ reached: [UsageLimitDTO], preventsAppDelete: Bool)
}

final class ManagedSettingsDailyLimitShield: DailyLimitShielding {
    private let store = ManagedSettingsStore(named: .dailyLimits)

    func apply(_ reached: [UsageLimitDTO], preventsAppDelete: Bool) {
        store.applyDailyLimits(reached, preventsAppDelete: preventsAppDelete)
    }
}

final class InMemoryDailyLimitShield: DailyLimitShielding {
    private(set) var shieldedLimitIDs: [UUID] = []
    private(set) var preventsAppDelete = false
    private(set) var applyCount = 0

    func apply(_ reached: [UsageLimitDTO], preventsAppDelete: Bool) {
        shieldedLimitIDs = reached.map(\.id)
        self.preventsAppDelete = preventsAppDelete && !reached.isEmpty
        applyCount += 1
    }
}
