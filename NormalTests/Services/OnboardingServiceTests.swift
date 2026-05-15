@testable import Normal
import Testing

@MainActor
struct OnboardingServiceTests {
    @Test func startsAtWelcome() {
        let s = OnboardingService()
        #expect(s.currentStep == .welcome)
        #expect(s.isOnboardingActive)
    }

    @Test func nextProgressesThroughSteps() {
        let s = OnboardingService()
        s.next()
        #expect(s.currentStep == .screenTimePermission)
        s.next()
        #expect(s.currentStep == .tabHome)
    }

    @Test func nextOnLastTabCompletes() {
        let s = OnboardingService()
        s.currentStep = .tabSchedules
        s.next()
        #expect(s.currentStep == .complete)
        #expect(!s.isOnboardingActive)
    }

    @Test func skipMarksComplete() {
        let s = OnboardingService()
        s.skip()
        #expect(s.currentStep == .complete)
        #expect(!s.isOnboardingActive)
    }

    @Test func requiredTabReflectsCurrentStep() {
        let s = OnboardingService()
        s.currentStep = .tabKeys
        #expect(s.requiredTab == .keys)
    }

    @Test func isTabWalkthroughTrueOnlyForTabSteps() {
        let s = OnboardingService()
        s.currentStep = .welcome
        #expect(!s.isTabWalkthrough)
        s.currentStep = .tabHome
        #expect(s.isTabWalkthrough)
    }
}
