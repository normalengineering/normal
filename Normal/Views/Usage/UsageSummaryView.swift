import SwiftData
import SwiftUI

struct UsageSummaryView: View {
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]

    var body: some View {
        let states = usageLimitService.states(for: limits)
        let reachedCount = states.values.filter { $0 == .reached }.count
        let worstState = states.values.max() ?? .under

        Section("Max Daily Limits") {
            NavigationLink {
                UsageView()
            } label: {
                SummaryRow(
                    systemImage: limits.isEmpty ? "hourglass" : worstState.icon,
                    tint: limits.isEmpty ? .secondary : worstState.color,
                    title: title(reachedCount: reachedCount),
                    subtitle: subtitle(reachedCount: reachedCount, worstState: worstState)
                )
            }
            .accessibilityIdentifier("settings.maxDailyLimitsLink")
        }
    }

    private func title(reachedCount: Int) -> Text {
        if limits.isEmpty { return Text("No Max Daily Limits") }
        if reachedCount > 0 { return Text("\(reachedCount) of \(limits.count) Reached") }
        return Text("\(limits.count) Max Daily Limits")
    }

    private func subtitle(reachedCount: Int, worstState: UsageLimitState) -> Text {
        if limits.isEmpty { return Text("Cap how long you can use apps each day") }
        let reset = usageLimitService.nextReset().formatted(date: .omitted, time: .shortened)
        if usageLimitService.isDayOverridden() { return Text("Paused until \(reset)") }
        if reachedCount > 0 { return Text("Resets at \(reset)") }
        return Text(worstState.label)
    }
}
