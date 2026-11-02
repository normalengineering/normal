import SwiftData
import SwiftUI

struct UsageSummaryView: View {
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]

    var body: some View {
        let states = usageLimitService.states(for: limits)
        let reachedCount = states.values.filter { $0 == .reached }.count
        let worstState = states.values.max() ?? .under

        NavigationLink {
            UsageView()
        } label: {
            HStack {
                Text("Max Daily Limits")
                    .foregroundStyle(.primary)
                Spacer()
                status(reachedCount: reachedCount, worstState: worstState)
            }
        }
        .accessibilityIdentifier("settings.maxDailyLimitsLink")
    }

    @ViewBuilder
    private func status(reachedCount: Int, worstState: UsageLimitState) -> some View {
        if limits.isEmpty {
            EmptyView()
        } else if usageLimitService.isDayOverridden() {
            Text("Paused")
                .foregroundStyle(.secondary)
        } else if reachedCount > 0 {
            Text("\(reachedCount) of \(limits.count) Reached")
                .foregroundStyle(worstState.color)
        } else if worstState == .warning {
            Text(worstState.label)
                .foregroundStyle(worstState.color)
        } else {
            Text("\(limits.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
