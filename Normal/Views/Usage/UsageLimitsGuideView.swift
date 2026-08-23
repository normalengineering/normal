import SwiftUI

struct UsageLimitsGuideView: View {
    let onAddLimit: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                Button("Add Limit", action: onAddLimit)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("usage.emptyAddLimit")
            }
            .padding(.vertical, DS.Spacing.sm)
            .standaloneListRow()
        }

        Section("How It Works") {
            FeatureRow(systemImage: "square.grid.2x2.fill", text: "Pick apps, websites, or categories. You can group multiple apps in a single limit.")
            FeatureRow(systemImage: "timer", text: "Choose how much time they get each day. Time you've already used today counts.")
            FeatureRow(systemImage: "lock.fill", text: "When the time runs out, they stay blocked until the reset. Only Emergency Unblock lifts them early.", tint: .red)
            FeatureRow(systemImage: "pencil", text: "Tighten anytime: lowering a limit or adding apps always works. After creating a limit raising or deleting it is allowed once every 7 days.", tint: .orange)
            FeatureRow(systemImage: "arrow.counterclockwise", text: "Every limit resets at the time you set. Once you have limits, it can be changed once every 7 days. Unused time doesn't carry over.")
        }

        Section("Ideas") {
            FeatureRow(systemImage: "bubble.left.and.bubble.right.fill", text: "30 minutes a day across all your social apps", tint: .orange)
            FeatureRow(systemImage: "gamecontroller.fill", text: "1 hour a day for games", tint: .orange)
            FeatureRow(systemImage: "newspaper.fill", text: "15 minutes a day for news or shopping websites", tint: .orange)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Image(systemName: "hourglass")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("No Max Daily Limits").font(.title2.bold())
            Text("Cap how long you can use apps each day. Once a limit runs out, those apps stay blocked until the day is over, even if you unblock with a key.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
