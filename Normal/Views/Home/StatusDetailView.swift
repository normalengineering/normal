import FamilyControls
import SwiftData
import SwiftUI

struct StatusDetailView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query(sort: [SortDescriptor(\BlockSchedule.sortIndex)]) private var schedules: [BlockSchedule]
    @Query private var allSettings: [Settings]

    let mainSelection: SelectedApps

    private var selection: FamilyActivitySelection { mainSelection.selection }

    private var customDomains: [String] {
        (allSettings.first?.enableCustomDomains ?? false) ? mainSelection.customDomains : []
    }

    private var overallStatus: BlockStatus {
        screenTimeService.blockStatus(selection: selection, customDomains: customDomains)
    }

    private var summary: ScheduleSummary {
        ScheduleSummary(schedules: schedules)
    }

    private var visibility: BlockedItemVisibility {
        BlockedItemVisibility(hideBlocked: allSettings.first?.hideBlockedApps ?? false)
    }

    private var appKinds: [SelectedTokenKind] {
        selection.applicationTokens.sortedStably.map(SelectedTokenKind.application)
    }

    private var websiteKinds: [SelectedTokenKind] {
        selection.webDomainTokens.sortedStably.map(SelectedTokenKind.webDomain)
    }

    private var categoryKinds: [SelectedTokenKind] {
        selection.categoryTokens.sortedStably.map(SelectedTokenKind.category)
    }

    // Custom domains are filtered as a group: the shield store tracks them as one
    // filter list, so they follow the overall status like their rows already do.
    private var areCustomDomainsBlocked: Bool { overallStatus != .none }

    private var visibleCustomDomains: [String] {
        visibility.visible(customDomains) { _ in areCustomDomainsBlocked }
    }

    private var hiddenCount: Int {
        visibility.hiddenCount(appKinds + websiteKinds + categoryKinds) { screenTimeService.isShielded($0) }
            + visibility.hiddenCount(customDomains) { _ in areCustomDomainsBlocked }
    }

    var body: some View {
        List {
            overallSection
            tokenSection("Apps", kinds: appKinds)
            tokenSection("Websites", kinds: websiteKinds)
            tokenSection("Categories", kinds: categoryKinds)
            customDomainsSection
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
                    Text("\(screenTimeService.activeShieldCount()) of \(selection.count + customDomains.count) blocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if hiddenCount > 0 { hiddenNote }
        }
    }

    private var hiddenNote: some View {
        Label {
            if hiddenCount == 1 {
                Text("1 blocked item hidden")
            } else {
                Text("\(hiddenCount) blocked items hidden")
            }
        } icon: {
            Image(systemName: "eye.slash")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("status.hiddenNote")
    }

    @ViewBuilder
    private var customDomainsSection: some View {
        if !visibleCustomDomains.isEmpty {
            Section("Custom Domains") {
                ForEach(visibleCustomDomains, id: \.self) { domain in
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
        let shown = visibility.visible(kinds) { screenTimeService.isShielded($0) }
        if !shown.isEmpty {
            Section(title) {
                ForEach(shown, id: \.self, content: tokenRow)
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
