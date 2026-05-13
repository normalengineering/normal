import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(OnboardingService.self) private var onboardingService
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [Settings]

    @State private var selectedTab: AppTab = .home

    private var settings: Settings? { allSettings.first }

    var body: some View {
        ZStack {
            MainTabView(selectedTab: $selectedTab)

            if onboardingService.isOnboardingActive {
                OnboardingOverlayView()
            }
        }
        .onChange(of: onboardingService.requiredTab) { _, newTab in
            if let newTab {
                selectedTab = newTab
            }
        }
        .onChange(of: onboardingService.isOnboardingActive) { _, isActive in
            if !isActive {
                settings?.hasCompletedOnboarding = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await screenTimeService.checkAuthorizationStatus() }
            }
        }
        .onAppear {
            if settings?.hasCompletedOnboarding == true {
                onboardingService.isOnboardingActive = false
                onboardingService.currentStep = .complete
                selectedTab = settings?.defaultTab ?? .home
            }
            Task { await screenTimeService.checkAuthorizationStatus() }
        }
    }
}
