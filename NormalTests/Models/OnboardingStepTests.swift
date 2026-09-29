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

    @Test func nextFromLastTabGoesToFinish() {
        #expect(OnboardingStep.tabSchedules.next() == .finish)
    }

    @Test func finishIsNotTabWalkthroughAndGoesToComplete() {
        #expect(OnboardingStep.finish.requiredTab == nil)
        #expect(!OnboardingStep.finish.isTabWalkthrough)
        #expect(OnboardingStep.finish.next() == .complete)
    }

    @Test func nextFromCompleteStaysComplete() {
        #expect(OnboardingStep.complete.next() == .complete)
    }

    @Test func nonTabStepsHaveNoTitle() {
        for step in [OnboardingStep.welcome, .screenTimePermission, .finish, .complete] {
            #expect(step.title == nil)
            #expect(step.description == nil)
        }
    }

    @Test func tabStepsHaveTitleAndDescription() {
        for step in [OnboardingStep.tabHome, .tabAppSelect, .tabKeys, .tabGroups, .tabSchedules] {
            #expect(step.title != nil)
            #expect(step.description != nil)
        }
    }
}
