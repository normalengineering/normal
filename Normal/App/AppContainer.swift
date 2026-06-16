import SwiftUI

struct AppContainer: View {
    @State private var screenTimeService: ScreenTimeService
    @State private var timedUnblockService: TimedUnblockService
    @State private var nfcService = NFCService.shared
    @State private var qrService = QRService.shared
    @State private var locationService = LocationService.shared
    @State private var keyManager = KeyManager()
    @State private var scheduleService: ScheduleService
    @State private var onboardingService = OnboardingService()
    @State private var appReviewService: AppReviewService
    @State private var emergencyUnblockService: EmergencyUnblockService
    @State private var donationService = DonationService()

    init() {
        let screenTime = ScreenTimeService()
        _screenTimeService = State(initialValue: screenTime)

        if UITestSupport.isActive {
            let center = UITestDeviceActivityCenter()
            let store = SharedStore(
                defaults: UserDefaults(suiteName: "uitest-\(UUID().uuidString)")
            )
            _timedUnblockService = State(initialValue: TimedUnblockService(
                activityCenter: center,
                sharedStore: store,
                onExpiration: { screenTime.notifyUpdate() }
            ))
            _scheduleService = State(initialValue: ScheduleService(
                activityCenter: center,
                sharedStore: store
            ))
            _appReviewService = State(initialValue: AppReviewService(
                defaults: UserDefaults(suiteName: "uitest-review-\(UUID().uuidString)")!
            ))
            _emergencyUnblockService = State(initialValue: EmergencyUnblockService(
                ledger: InMemoryEmergencyUnblockLedger()
            ))
        } else {
            _timedUnblockService = State(initialValue: TimedUnblockService(
                onExpiration: { screenTime.notifyUpdate() }
            ))
            _scheduleService = State(initialValue: ScheduleService())
            _appReviewService = State(initialValue: AppReviewService())
            _emergencyUnblockService = State(initialValue: EmergencyUnblockService(
                ledger: KeychainEmergencyUnblockLedger()
            ))
        }
    }

    var body: some View {
        ContentView()
            .environment(screenTimeService)
            .environment(nfcService)
            .environment(qrService)
            .environment(locationService)
            .environment(keyManager)
            .environment(timedUnblockService)
            .environment(scheduleService)
            .environment(onboardingService)
            .environment(appReviewService)
            .environment(emergencyUnblockService)
            .environment(donationService)
    }
}
