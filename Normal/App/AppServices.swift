import DeviceActivity
import Foundation

@MainActor
final class AppServices {
    let screenTime: ScreenTimeService
    let timedUnblock: TimedUnblockService
    let schedule: ScheduleService
    let appReview: AppReviewService
    let emergencyUnblock: EmergencyUnblockService
    let usageLimit: UsageLimitService
    let unlockInbox = UnlockRequestInbox()

    init() {
        if UITestSupport.isActive {
            let center = UITestDeviceActivityCenter()
            let store = SharedStore(
                defaults: UserDefaults(suiteName: "uitest-\(UUID().uuidString)")
            )
            store.setCustomDomainsEnabled(UITestSupport.customDomains)
            if let usedMinutes = UITestSupport.usageMinutesToday {
                center.onUsageLimitsStarted = { events in
                    for (name, event) in events
                    where event.includesPastActivity
                        && (event.threshold.hour ?? 0) * 60 + (event.threshold.minute ?? 0) <= usedMinutes
                    {
                        if let id = SharedConstants.usageLimitID(fromEventName: name.rawValue) {
                            store.recordUsageState(.reached, for: id)
                        }
                    }
                }
            }
            let screenTime = ScreenTimeService(sharedStore: store, activityCenter: center)
            self.screenTime = screenTime
            timedUnblock = TimedUnblockService(
                activityCenter: center,
                sharedStore: store,
                onExpiration: { screenTime.reconcile() }
            )
            schedule = ScheduleService(activityCenter: center, sharedStore: store)
            appReview = AppReviewService(
                defaults: UserDefaults(suiteName: "uitest-review-\(UUID().uuidString)")!
            )
            emergencyUnblock = EmergencyUnblockService(ledger: InMemoryEmergencyUnblockLedger())
            usageLimit = UsageLimitService(
                activityCenter: center,
                sharedStore: store,
                ledger: InMemoryUsageLimitLedger()
            )
        } else {
            let screenTime = ScreenTimeService()
            self.screenTime = screenTime
            timedUnblock = TimedUnblockService(onExpiration: { screenTime.reconcile() })
            schedule = ScheduleService()
            appReview = AppReviewService()
            emergencyUnblock = EmergencyUnblockService(ledger: KeychainEmergencyUnblockLedger())
            usageLimit = UsageLimitService()
        }
    }
}
