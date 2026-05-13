@testable import Normal
import Testing

struct OnboardingServiceTests {
    @Test @MainActor func initialState() {
        let service = OnboardingService()
        #expect(service.currentStep == .welcome)
        #expect(service.isOnboardingActive)
    }

    @Test @MainActor func nextAdvancesOneStep() {
        let service = OnboardingService()
        service.next()
        #expect(service.currentStep == .screenTimePermission)
    }

    @Test @MainActor func nextThroughAllStepsCompletesOnboarding() {
        let service = OnboardingService()

        let expectedSteps: [OnboardingStep] = [
            .screenTimePermission, .tabHome, .tabAppSelect,
            .tabKeys, .tabGroups, .tabSchedules,
        ]

        for expected in expectedSteps {
            service.next()
            #expect(service.currentStep == expected)
            #expect(service.isOnboardingActive)
        }

        service.next()
        #expect(service.currentStep == .complete)
        #expect(!service.isOnboardingActive)
    }

    @Test @MainActor func skipCompletesImmediately() {
        let service = OnboardingService()
        service.skip()
        #expect(service.currentStep == .complete)
        #expect(!service.isOnboardingActive)
    }

    @Test @MainActor func requiredTabMapping() {
        let service = OnboardingService()

        service.currentStep = .welcome
        #expect(service.requiredTab == nil)

        service.currentStep = .screenTimePermission
        #expect(service.requiredTab == nil)

        service.currentStep = .tabHome
        #expect(service.requiredTab == .home)

        service.currentStep = .tabAppSelect
        #expect(service.requiredTab == .appSelect)

        service.currentStep = .tabKeys
        #expect(service.requiredTab == .keys)

        service.currentStep = .tabGroups
        #expect(service.requiredTab == .groups)

        service.currentStep = .tabSchedules
        #expect(service.requiredTab == .schedules)

        service.currentStep = .complete
        #expect(service.requiredTab == nil)
    }

    @Test @MainActor func isTabWalkthrough() {
        let service = OnboardingService()

        service.currentStep = .welcome
        #expect(!service.isTabWalkthrough)

        service.currentStep = .screenTimePermission
        #expect(!service.isTabWalkthrough)

        service.currentStep = .tabHome
        #expect(service.isTabWalkthrough)

        service.currentStep = .complete
        #expect(!service.isTabWalkthrough)
    }

    @Test @MainActor func nextFromTabSchedulesCompletes() {
        let service = OnboardingService()
        service.currentStep = .tabSchedules
        service.next()
        #expect(service.currentStep == .complete)
        #expect(!service.isOnboardingActive)
    }
}
