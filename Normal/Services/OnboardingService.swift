import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class OnboardingService {
    var currentStep: OnboardingStep = .welcome
    var isOnboardingActive: Bool = true
    var highlightFrames: [OnboardingStep: CGRect] = [:]

    var requiredTab: AppTab? { currentStep.requiredTab }

    var isTabWalkthrough: Bool { currentStep.isTabWalkthrough }

    var highlightFrame: CGRect? { highlightFrames[currentStep] }

    func next() {
        let upcoming = currentStep.next()
        if upcoming == .complete {
            complete()
        } else {
            currentStep = upcoming
        }
    }

    func skip() {
        complete()
    }

    private func complete() {
        currentStep = .complete
        isOnboardingActive = false
    }
}
