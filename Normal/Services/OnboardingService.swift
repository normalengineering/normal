import Foundation
import Observation
import SwiftUI

enum OnboardingStep: String, CaseIterable {
    case welcome
    case screenTimePermission
    case tabHome
    case tabAppSelect
    case tabKeys
    case tabGroups
    case tabSchedules
    case complete
}

@MainActor
@Observable
class OnboardingService {
    var currentStep: OnboardingStep = .welcome
    var isOnboardingActive: Bool = true
    var highlightFrames: [OnboardingStep: CGRect] = [:]

    var requiredTab: AppTab? {
        switch currentStep {
        case .tabHome: .home
        case .tabAppSelect: .appSelect
        case .tabKeys: .keys
        case .tabGroups: .groups
        case .tabSchedules: .schedules
        default: nil
        }
    }

    var isTabWalkthrough: Bool {
        requiredTab != nil
    }

    var highlightFrame: CGRect? {
        highlightFrames[currentStep]
    }

    func next() {
        guard let index = OnboardingStep.allCases.firstIndex(of: currentStep),
              index + 1 < OnboardingStep.allCases.count
        else {
            completeOnboarding()
            return
        }
        let nextStep = OnboardingStep.allCases[index + 1]
        if nextStep == .complete {
            completeOnboarding()
        } else {
            currentStep = nextStep
        }
    }

    func skip() {
        completeOnboarding()
    }

    private func completeOnboarding() {
        currentStep = .complete
        isOnboardingActive = false
    }
}
