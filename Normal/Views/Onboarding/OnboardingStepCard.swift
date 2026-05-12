import SwiftUI

struct OnboardingStepCard: View {
    let title: String
    let description: String
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button("Skip") {
                    onSkip()
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button("Next") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }
}
