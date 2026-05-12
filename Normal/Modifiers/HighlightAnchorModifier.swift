import SwiftUI

struct HighlightAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [OnboardingStep: CGRect] = [:]

    static func reduce(value: inout [OnboardingStep: CGRect], nextValue: () -> [OnboardingStep: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct HighlightAnchorModifier: ViewModifier {
    let step: OnboardingStep

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: HighlightAnchorPreferenceKey.self,
                            value: [step: proxy.frame(in: .global)]
                        )
                }
            )
    }
}

extension View {
    func highlightAnchor(step: OnboardingStep) -> some View {
        modifier(HighlightAnchorModifier(step: step))
    }
}
