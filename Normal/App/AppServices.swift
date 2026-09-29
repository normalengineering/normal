import Foundation

@MainActor
final class AppServices {
    let screenTime: ScreenTimeService
    let timedUnblock: TimedUnblockService
    let schedule: ScheduleService
    let appReview: AppReviewService
    let emergencyUnblock: EmergencyUnblockService

    init() {
        let screenTime = ScreenTimeService()
        self.screenTime = screenTime

        if UITestSupport.isActive {
            let center = UITestDeviceActivityCenter()
            let store = SharedStore(
                defaults: UserDefaults(suiteName: "uitest-\(UUID().uuidString)")
            )
            timedUnblock = TimedUnblockService(
                activityCenter: center,
                sharedStore: store,
                onExpiration: { screenTime.notifyUpdate() }
            )
            schedule = ScheduleService(activityCenter: center, sharedStore: store)
            appReview = AppReviewService(
                defaults: UserDefaults(suiteName: "uitest-review-\(UUID().uuidString)")!
            )
            emergencyUnblock = EmergencyUnblockService(ledger: InMemoryEmergencyUnblockLedger())
        } else {
            timedUnblock = TimedUnblockService(onExpiration: { screenTime.notifyUpdate() })
            schedule = ScheduleService()
            appReview = AppReviewService()
            emergencyUnblock = EmergencyUnblockService(ledger: KeychainEmergencyUnblockLedger())
        }
    }
}
