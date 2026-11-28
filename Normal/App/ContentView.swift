import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(OnboardingService.self) private var onboardingService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(EmergencyUnblockService.self) private var emergencyUnblockService
    @Environment(UsageLimitService.self) private var usageLimitService
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [Settings]
    @Query private var schedules: [BlockSchedule]
    @Query private var usageLimits: [UsageLimit]
    @Query private var selectedApps: [SelectedApps]

    @State private var navigationCoordinator = NavigationCoordinator()

    private var settings: Settings? {
        allSettings.first
    }

    var body: some View {
        ZStack {
            MainTabView(selectedTab: $navigationCoordinator.selectedTab)
            if onboardingService.isOnboardingActive {
                OnboardingOverlayView()
            }
        }
        .widgetActionResponder(coordinator: navigationCoordinator)
        .liveActivitySync()
        .sheet(isPresented: $navigationCoordinator.isSettingsPresented, onDismiss: navigationCoordinator.settingsDidDismiss) {
            SettingsView(initialTab: navigationCoordinator.settingsInitialTab)
        }
        .environment(\.navigationCoordinator, navigationCoordinator)
        .onChange(of: onboardingService.requiredTab) { _, newTab in
            if let newTab {
                navigationCoordinator.selectedTab = newTab
            }
        }
        .onChange(of: onboardingService.isOnboardingActive, onOnboardingCompleted)
        .onChange(of: usageLimits.count) { _, _ in reregisterUsageLimits() }
        .onChange(of: settings?.usageLimitConfig) { _, _ in reregisterUsageLimits() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await screenTimeService.checkAuthorizationStatus() }
                screenTimeService.notifyUpdate()
                timedUnblockService.refresh(screenTimeService: screenTimeService)
                // The monitor extension may have spent a limit while we were away.
                usageLimitService.notifyUpdate()
                reregisterActivities()
            }
        }
        .onAppear(perform: onAppear)
    }

    private func onAppear() {
        if let settings {
            emergencyUnblockService.reconcile(into: settings)
            scheduleService.mirrorCustomDomainsEnabled(settings.enableCustomDomains)
        }

        timedUnblockService.reconcile(screenTimeService: screenTimeService)
        if settings?.hasCompletedOnboarding == true {
            onboardingService.isOnboardingActive = false
            onboardingService.currentStep = .complete
            navigationCoordinator.selectedTab = settings?.defaultTab ?? .home
        }
        Task {
            await screenTimeService.checkAuthorizationStatus()
            if settings?.hasCompletedOnboarding == true {
                _ = await screenTimeService.ensureAuthorized()
                reregisterActivities()
            }
        }
    }

    private var mainSelectionConstraint: SelectionConstraint? {
        selectedApps.first?.effectiveConstraint(customDomainsEnabled: settings?.enableCustomDomains ?? false)
    }

    /// Re-registers every `DeviceActivity` we depend on. Usage limits ride along
    /// with schedules: their threshold events use `includesPastActivity`, so
    /// re-registering mid-day cannot hand back an allowance already spent.
    private func reregisterActivities() {
        guard settings?.hasCompletedOnboarding == true else { return }
        scheduleService.registerAll(
            schedules,
            screenTimeService: screenTimeService,
            constrainedTo: mainSelectionConstraint
        )
        reregisterUsageLimits()
    }

    private func reregisterUsageLimits() {
        guard let settings, settings.hasCompletedOnboarding else { return }
        usageLimitService.registerAll(usageLimits, config: settings.usageLimitConfig)
    }

    private func onOnboardingCompleted(_: Bool, _ isActive: Bool) {
        if !isActive, settings?.hasCompletedOnboarding != true {
            settings?.hasCompletedOnboarding = true
            navigationCoordinator.selectedTab = .appSelect
        }
    }
}
