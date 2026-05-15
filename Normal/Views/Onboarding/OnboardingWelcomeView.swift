import SwiftUI

struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    private static let features: [(systemImage: String, text: LocalizedStringKey)] = [
        ("app.dashed", "Select apps you want to block"),
        ("key.viewfinder", "Register NFC Tags and QR Codes to lock and unlock"),
        ("app.shadow", "Organize apps into groups"),
        ("calendar.badge.clock", "Create schedules"),
    ]

    var body: some View {
        PromptCard {
            Text("Welcome to Normal")
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.md + 2) {
                ForEach(Self.features, id: \.systemImage) { feature in
                    FeatureRow(systemImage: feature.systemImage, text: feature.text)
                }
            }
        } actions: {
            VStack(spacing: DS.Spacing.md) {
                PrimaryActionButton(title: "Get Started", action: onGetStarted)
                SecondaryTextButton(title: "Skip", action: onSkip)
            }
        }
    }
}
