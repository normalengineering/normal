import SwiftUI

struct OnboardingStepCard: View {
    let title: String
    let description: String
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title).font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                SecondaryTextButton(title: "Skip", action: onSkip)
                Spacer()
                Button("Next", action: onNext)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .glassCardBackground(cornerRadius: DS.Radius.lg)
        .padding(.horizontal)
    }
}
