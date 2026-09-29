import SwiftData
import SwiftUI

struct AppContainer: View {
    @Query private var allSettings: [Settings]
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

    init(services: AppServices) {
        _screenTimeService = State(initialValue: services.screenTime)
        _timedUnblockService = State(initialValue: services.timedUnblock)
        _scheduleService = State(initialValue: services.schedule)
        _appReviewService = State(initialValue: services.appReview)
        _emergencyUnblockService = State(initialValue: services.emergencyUnblock)
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
            .task { mirrorCustomDomainsEnabled() }
            .onChange(of: allSettings.first?.enableCustomDomains ?? false) { _, enabled in
                scheduleService.mirrorCustomDomainsEnabled(enabled)
                if !enabled { screenTimeService.clearCustomDomainFilter() }
            }
    }

    private func mirrorCustomDomainsEnabled() {
        scheduleService.mirrorCustomDomainsEnabled(allSettings.first?.enableCustomDomains ?? false)
    }
}
