import SwiftUI

struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 20) {
                Text("Welcome to Normal")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "app.dashed", text: "Select apps you want to block")
                    featureRow(icon: "key.viewfinder", text: "Register physical keys to lock and unlock")
                    featureRow(icon: "app.shadow", text: "Organize apps into groups")
                    featureRow(icon: "calendar.badge.clock", text: "Create schedules for automatic blocking")
                }

                VStack(spacing: 12) {
                    Button {
                        onGetStarted()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Skip") {
                        onSkip()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .glassEffect(in: .rect(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(.subheadline)
        }
    }
}
