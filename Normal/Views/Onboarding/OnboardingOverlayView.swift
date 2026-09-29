import SwiftUI

struct OnboardingOverlayView: View {
    @Environment(OnboardingService.self) private var onboardingService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.navigationCoordinator) private var navigationCoordinator

    var body: some View {
        ZStack {
            switch onboardingService.currentStep {
            case .welcome:
                scrim
                OnboardingWelcomeView(
                    onGetStarted: { onboardingService.next() },
                    onSkip: { onboardingService.skip() }
                )

            case .screenTimePermission:
                scrim
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

            case .finish:
                scrim
                OnboardingFinishView(
                    onDone: { onboardingService.next() },
                    onViewFAQ: {
                        onboardingService.next()
                        navigationCoordinator.presentSettings(tab: .faq)
                    }
                )

            case .complete:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingService.currentStep)
    }

    private var scrim: some View {
        Color.black
            .opacity(DS.Opacity.scrim)
            .ignoresSafeArea()
    }

    private var tabWalkthroughOverlay: some View {
        let step = onboardingService.currentStep
        return ZStack {
            scrim.allowsHitTesting(false)
            VStack {
                Spacer()
                if let title = step.title, let description = step.description {
                    OnboardingStepCard(
                        title: title,
                        description: description,
                        onNext: { onboardingService.next() },
                        onSkip: { onboardingService.skip() }
                    )
                }
                Spacer().frame(height: 100)
            }
        }
    }
}
