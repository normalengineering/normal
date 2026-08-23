import SwiftData
import SwiftUI

/// The Usage row under Status on Home. Reports today's standing at a glance and
/// pushes into the full limits screen.
struct UsageSummaryView: View {
    @Environment(UsageLimitService.self) private var usageLimitService

    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]

    private var worstState: UsageLimitState {
        limits
            .map { usageLimitService.state(for: $0) }
            .max() ?? .under
    }

    private var spentCount: Int {
        limits.filter { usageLimitService.state(for: $0) == .reached }.count
    }

    var body: some View {
        Section("Usage") {
            NavigationLink {
                UsageView()
            } label: {
                SummaryRow(
                    systemImage: limits.isEmpty ? "hourglass" : worstState.icon,
                    tint: limits.isEmpty ? .secondary : worstState.color,
                    title: title,
                    subtitle: subtitle
                )
            }
            .accessibilityIdentifier("home.usageLink")
        }
    }

    private var title: LocalizedStringKey {
        if limits.isEmpty { return "No App Limits" }
        if spentCount > 0 { return "\(spentCount) of \(limits.count) Used Up" }
        return "\(limits.count) App Limits"
    }

    private var subtitle: String {
        if limits.isEmpty {
            return String(localized: "Cap how long you can use an app each day")
        }
        if spentCount > 0 {
            return String(
                localized: "Resets at \(usageLimitService.nextReset().formatted(date: .omitted, time: .shortened))"
            )
        }
        return worstState.shortLabel
    }
}
