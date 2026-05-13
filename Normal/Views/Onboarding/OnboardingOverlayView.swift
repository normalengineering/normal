import SwiftUI

struct OnboardingOverlayView: View {
    @Environment(OnboardingService.self) private var onboardingService
    @Environment(ScreenTimeService.self) private var screenTimeService

    var body: some View {
        ZStack {
            switch onboardingService.currentStep {
            case .welcome:
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                OnboardingWelcomeView(
                    onGetStarted: { onboardingService.next() },
                    onSkip: { onboardingService.skip() }
                )

            case .screenTimePermission:
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ScreenTimePermissionCard(
                    onGrant: {
                        Task {
                            await screenTimeService.requestAuthorization()
                            onboardingService.next()
                        }
                    },
                    onSkip: { onboardingService.next() }
                )

            case .tabHome, .tabAppSelect, .tabKeys, .tabGroups, .tabSchedules:
                tabWalkthroughOverlay

            case .complete:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingService.currentStep)
    }

    private var tabWalkthroughOverlay: some View {
        let step = onboardingService.currentStep

        return ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                Spacer()

                OnboardingStepCard(
                    title: stepTitle(for: step),
                    description: stepDescription(for: step),
                    onNext: { onboardingService.next() },
                    onSkip: { onboardingService.skip() }
                )

                Spacer()
                    .frame(height: 100)
            }
        }
    }

    private func stepTitle(for step: OnboardingStep) -> String {
        switch step {
        case .tabHome: "Home"
        case .tabAppSelect: "App Select"
        case .tabKeys: "Keys"
        case .tabGroups: "Groups"
        case .tabSchedules: "Schedules"
        default: ""
        }
    }

    private func stepDescription(for step: OnboardingStep) -> String {
        switch step {
        case .tabHome: "View your block status and quickly block or unblock all your selected apps."
        case .tabAppSelect: "Choose which apps you want Normal to manage. These are the apps that can be blocked."
        case .tabKeys: "Register NFC tags or QR codes as physical keys to lock and unlock your apps."
        case .tabGroups: "Organize your apps into groups so you can block and unblock them separately."
        case .tabSchedules: "Set up automatic schedules to block apps at certain times and days."
        default: ""
        }
    }
}
