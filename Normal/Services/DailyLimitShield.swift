import Foundation
import ManagedSettings

protocol DailyLimitShielding: AnyObject {
    func apply(_ reached: [UsageLimitDTO])
}

final class ManagedSettingsDailyLimitShield: DailyLimitShielding {
    private let store = ManagedSettingsStore(named: .dailyLimits)

    func apply(_ reached: [UsageLimitDTO]) {
        store.applyDailyLimits(reached)
    }
}

final class InMemoryDailyLimitShield: DailyLimitShielding {
    private(set) var shieldedLimitIDs: [UUID] = []
    private(set) var applyCount = 0

    func apply(_ reached: [UsageLimitDTO]) {
        shieldedLimitIDs = reached.map(\.id)
        applyCount += 1
    }
}
