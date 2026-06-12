import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(OnboardingService.self) private var onboardingService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(EmergencyUnblockService.self) private var emergencyUnblockService
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [Settings]
    @Query private var schedules: [BlockSchedule]

    @State private var selectedTab: AppTab = .home
    @State private var navigationCoordinator = NavigationCoordinator()

    private var settings: Settings? { allSettings.first }

    var body: some View {
        ZStack {
            MainTabView(selectedTab: $selectedTab)
            if onboardingService.isOnboardingActive {
                OnboardingOverlayView()
            }
        }
        .environment(\.navigationCoordinator, navigationCoordinator)
        .sheet(isPresented: $navigationCoordinator.isSettingsPresented) {
            SettingsView(initialTab: navigationCoordinator.settingsInitialTab)
        }
        .onChange(of: onboardingService.requiredTab) { _, newTab in
            if let newTab { selectedTab = newTab }
        }
        .onChange(of: onboardingService.isOnboardingActive, onOnboardingCompleted)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await screenTimeService.checkAuthorizationStatus() }
                screenTimeService.notifyUpdate()
                timedUnblockService.refresh()
                reregisterSchedules()
            }
        }
        .onAppear(perform: onAppear)
    }

    private func onAppear() {
        if let settings {
            emergencyUnblockService.reconcile(into: settings)
        }
        if settings?.hasCompletedOnboarding == true {
            onboardingService.isOnboardingActive = false
            onboardingService.currentStep = .complete
            selectedTab = settings?.defaultTab ?? .home
        }
        Task {
            await screenTimeService.checkAuthorizationStatus()
            if settings?.hasCompletedOnboarding == true {
                _ = await screenTimeService.ensureAuthorized()
                reregisterSchedules()
            }
        }
    }

    private func reregisterSchedules() {
        guard settings?.hasCompletedOnboarding == true else { return }
        scheduleService.registerAll(schedules, screenTimeService: screenTimeService)
    }

    private func onOnboardingCompleted(_: Bool, _ isActive: Bool) {
        if !isActive, settings?.hasCompletedOnboarding != true {
            settings?.hasCompletedOnboarding = true
            selectedTab = .appSelect
        }
    }
}
