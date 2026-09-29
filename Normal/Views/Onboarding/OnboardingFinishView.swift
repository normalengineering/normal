import SwiftUI

struct OnboardingFinishView: View {
    let onDone: () -> Void
    let onViewFAQ: () -> Void

    private static let notes: [(systemImage: String, text: LocalizedStringKey)] = [
        ("lock.open", "To make changes to apps, keys, groups, or schedules, all apps must be unblocked."),
        ("lock.shield", "Normal can be made impossible to bypass. Instructions are in Normal's Settings > FAQ."),
    ]

    var body: some View {
        PromptCard {
            Text("You're All Set")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.md + 2) {
                ForEach(Self.notes, id: \.systemImage) { note in
                    FeatureRow(systemImage: note.systemImage, text: note.text)
                }
            }
        } actions: {
            VStack(spacing: DS.Spacing.md) {
                PrimaryActionButton(title: "Done", action: onDone)
                    .accessibilityIdentifier("onboarding.done")
                SecondaryTextButton(title: "View FAQ", action: onViewFAQ)
                    .accessibilityIdentifier("onboarding.viewFAQ")
            }
        }
    }
}
