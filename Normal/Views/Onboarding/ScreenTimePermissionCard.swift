import SwiftUI

struct ScreenTimePermissionCard: View {
    var onGrant: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        PromptCard {
            Label("Screen Time Permission", systemImage: "hourglass")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Normal uses Screen Time to block and unblock apps. You can grant this now or later, it's required to select and block apps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } actions: {
            VStack(spacing: DS.Spacing.md) {
                PrimaryActionButton(title: "Grant Permission", action: onGrant)
                if let onSkip {
                    SecondaryTextButton(title: "Skip", action: onSkip)
                }
            }
        }
    }
}
