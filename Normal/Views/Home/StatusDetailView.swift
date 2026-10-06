import FamilyControls
import SwiftData
import SwiftUI

struct StatusDetailView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(UsageLimitService.self) private var usageLimitService
    @Query(sort: [SortDescriptor(\BlockSchedule.sortIndex)]) private var schedules: [BlockSchedule]
    @Query(sort: [SortDescriptor(\UsageLimit.sortIndex)]) private var limits: [UsageLimit]
    @Query private var allSettings: [Settings]

    let mainSelection: SelectedApps

    private var selection: FamilyActivitySelection {
        mainSelection.selection
    }

    private var customDomains: [String] {
        (allSettings.first?.enableCustomDomains ?? false) ? mainSelection.customDomains : []
    }

    private var overallStatus: BlockStatus {
        screenTimeService.blockStatus(selection: selection, customDomains: customDomains)
    }

    private var summary: ScheduleSummary {
        ScheduleSummary(schedules: schedules)
    }

    var body: some View {
        List {
            overallSection
            if !limits.isEmpty {
                limitsSection
            }
            tokenSection("Apps", kinds: selection.applicationTokens.sortedStably.map(SelectedTokenKind.application))
            tokenSection("Websites", kinds: selection.webDomainTokens.sortedStably.map(SelectedTokenKind.webDomain))
            tokenSection("Categories", kinds: selection.categoryTokens.sortedStably.map(SelectedTokenKind.category))
            customDomainsSection
            if !schedules.isEmpty {
                schedulesSection
            }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overallSection: some View {
        Section("Status") {
            SummaryRow(
                systemImage: overallStatus.icon,
                tint: overallStatus.color,
                title: Text(LocalizedStringKey(overallStatus.title)),
                subtitle: Text(
                    "\(screenTimeService.activeShieldCount()) of \(selection.count + customDomains.count) blocked"
                )
            )
        }
    }

    private var limitsSection: some View {
        let states = usageLimitService.states(for: limits)
        let isPaused = usageLimitService.isDayOverridden()
        let reset = usageLimitService.nextReset().formatted(date: .omitted, time: .shortened)
        return Section {
            ForEach(limits) { limit in
                limitRow(limit, state: states[limit.id] ?? .under, isPaused: isPaused)
            }
        } header: {
            Text("Max Daily Limits")
        } footer: {
            Text(isPaused ? "Paused by emergency unblock until \(reset)." : "Resets at \(reset).")
        }
    }

    private func limitRow(_ limit: UsageLimit, state: UsageLimitState, isPaused: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                SelectionIconsView(tokens: limit.selection.allTokens, limit: 5)
                Text("\(limit.selection.selectedTokenCounts) · \(DurationFormat.compact(minutes: limit.minutesPerDay)) a day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isPaused {
                StatusBadge(title: "Paused", systemImage: "pause.circle.fill", tint: .secondary)
            } else {
                StatusBadge(title: state.label, systemImage: state.icon, tint: state.color)
            }
        }
    }

    @ViewBuilder
    private var customDomainsSection: some View {
        if !customDomains.isEmpty {
            Section("Custom Domains") {
                ForEach(customDomains, id: \.self) { domain in
                    HStack {
                        Label(domain, systemImage: "globe")
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                        Spacer()
                        let status: BlockStatus = overallStatus == .none ? .none : .all
                        StatusBadge(
                            title: LocalizedStringKey(status.shortLabel),
                            systemImage: status.icon,
                            tint: status.color
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tokenSection(_ title: LocalizedStringKey, kinds: [SelectedTokenKind]) -> some View {
        if !kinds.isEmpty {
            Section(title) {
                ForEach(kinds, id: \.self, content: tokenRow)
            }
        }
    }

    private func tokenRow(_ kind: SelectedTokenKind) -> some View {
        let status: BlockStatus = screenTimeService.isShielded(kind) ? .all : .none
        return HStack {
            SelectionTokenLabel(kind: kind)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            Spacer()
            StatusBadge(
                title: LocalizedStringKey(status.shortLabel),
                systemImage: status.icon,
                tint: status.color
            )
        }
    }

    private var schedulesSection: some View {
        Section("Schedules") {
            summaryRow("On", systemImage: "checkmark.circle.fill", tint: .green, value: summary.enabled)
            summaryRow("Off", systemImage: "pause.circle.fill", tint: .secondary, value: summary.disabled)
            summaryRow("Active now", systemImage: "clock.fill", tint: .orange, value: summary.activeNow)
        }
    }

    private func summaryRow(
        _ title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        value: Int
    ) -> some View {
        LabeledContent {
            Text("\(value)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(tint)
        }
    }
}
