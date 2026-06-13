import FamilyControls
import SwiftData
import SwiftUI

struct StatusDetailView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query(sort: [SortDescriptor(\BlockSchedule.sortIndex)]) private var schedules: [BlockSchedule]

    let mainSelection: SelectedApps

    private var selection: FamilyActivitySelection { mainSelection.selection }

    private var overallStatus: BlockStatus {
        screenTimeService.blockStatus(selection: selection)
    }

    private var summary: ScheduleSummary {
        ScheduleSummary(schedules: schedules)
    }

    var body: some View {
        List {
            overallSection
            tokenSection("Apps", kinds: selection.applicationTokens.sortedStably.map(SelectedTokenKind.application))
            tokenSection("Websites", kinds: selection.webDomainTokens.sortedStably.map(SelectedTokenKind.webDomain))
            tokenSection("Categories", kinds: selection.categoryTokens.sortedStably.map(SelectedTokenKind.category))
            if !schedules.isEmpty { schedulesSection }
        }
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overallSection: some View {
        Section("Status") {
            HStack(spacing: DS.Spacing.lg - 1) {
                Image(systemName: overallStatus.icon)
                    .font(.title)
                    .foregroundStyle(overallStatus.color)
                VStack(alignment: .leading) {
                    Text(overallStatus.title)
                        .font(.headline)
                    Text("\(screenTimeService.activeShieldCount()) of \(selection.count) blocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
