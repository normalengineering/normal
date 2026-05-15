import SwiftUI

struct AppContainer: View {
    @State private var screenTimeService: ScreenTimeService
    @State private var timedUnblockService: TimedUnblockService
    @State private var nfcService = NFCService.shared
    @State private var qrService = QRService.shared
    @State private var keyManager = KeyManager()
    @State private var scheduleService = ScheduleService()
    @State private var onboardingService = OnboardingService()

    init() {
        let screenTime = ScreenTimeService()
        _screenTimeService = State(initialValue: screenTime)
        _timedUnblockService = State(initialValue: TimedUnblockService(
            onExpiration: { screenTime.notifyUpdate() }
        ))
    }

    var body: some View {
        ContentView()
            .environment(screenTimeService)
            .environment(nfcService)
            .environment(qrService)
            .environment(keyManager)
            .environment(timedUnblockService)
            .environment(scheduleService)
            .environment(onboardingService)
    }
}
