@testable import Normal
import Testing

struct OnboardingStepTests {
    @Test func welcomeHasNoRequiredTab() {
        #expect(OnboardingStep.welcome.requiredTab == nil)
        #expect(!OnboardingStep.welcome.isTabWalkthrough)
    }

    @Test func tabStepsMapToTabs() {
        #expect(OnboardingStep.tabHome.requiredTab == .home)
        #expect(OnboardingStep.tabAppSelect.requiredTab == .appSelect)
        #expect(OnboardingStep.tabKeys.requiredTab == .keys)
        #expect(OnboardingStep.tabGroups.requiredTab == .groups)
        #expect(OnboardingStep.tabSchedules.requiredTab == .schedules)
    }

    @Test func tabStepsAreTabWalkthrough() {
        #expect(OnboardingStep.tabHome.isTabWalkthrough)
        #expect(OnboardingStep.tabAppSelect.isTabWalkthrough)
    }

    @Test func completeHasNoRequiredTab() {
        #expect(OnboardingStep.complete.requiredTab == nil)
    }

    @Test func nextProgressesLinearly() {
        #expect(OnboardingStep.welcome.next() == .screenTimePermission)
        #expect(OnboardingStep.screenTimePermission.next() == .tabHome)
        #expect(OnboardingStep.tabHome.next() == .tabAppSelect)
    }

    @Test func nextFromLastTabGoesToComplete() {
        #expect(OnboardingStep.tabSchedules.next() == .complete)
    }

    @Test func nextFromCompleteStaysComplete() {
        #expect(OnboardingStep.complete.next() == .complete)
    }

    @Test func nonTabStepsHaveEmptyTitle() {
        #expect(OnboardingStep.welcome.title.isEmpty)
        #expect(OnboardingStep.complete.title.isEmpty)
    }

    @Test func tabStepsHaveTitleAndDescription() {
        for step in [OnboardingStep.tabHome, .tabAppSelect, .tabKeys, .tabGroups, .tabSchedules] {
            #expect(!step.title.isEmpty)
            #expect(!step.description.isEmpty)
        }
    }
}
