import FamilyControls
import SwiftData
import SwiftUI

struct ScheduleCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var allSchedules: [BlockSchedule]
    @Query private var keys: [Key]
    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]

    let schedule: BlockSchedule

    private var customDomains: [String] {
        (allSettings.first?.enableCustomDomains ?? false) ? schedule.customDomains : []
    }

    @State private var isEditing = false
    @State private var isReselecting = false
    @State private var showDeleteConfirmation = false
    @State private var showToggleConfirmation = false
    @State private var error: Error?

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasKeys: Bool { !keys.isEmpty }

    private var needsSync: Bool {
        guard let main = selectedApps.first else { return false }
        if !schedule.selection.isSubset(of: main.selection) { return true }
        if allSettings.first?.enableCustomDomains ?? false,
           CustomDomains.needsResync(schedule.customDomains, main: main.customDomains) { return true }
        return false
    }

    private var isLocked: Bool { isBlocked || !hasKeys || needsSync }

    var body: some View {
        GlassCard {
            header
            timingRow
            weekdayChips
            tokenStrip
            if needsSync {
                syncWarningText
            }
        }
        .opacity((schedule.isEnabled && !isLocked) ? 1 : DS.Opacity.dim)
        .onTapGesture {
            if needsSync { isReselecting = true } else if !isLocked { isEditing = true }
        }
        .editDeleteContextMenu(
            isDisabled: isLocked && !needsSync,
            onEdit: { if needsSync { isReselecting = true } else { isEditing = true } },
            onDelete: { showDeleteConfirmation = true }
        )
        .sheet(isPresented: $isEditing) {
            ScheduleFormSheet(existing: schedule)
        }
        .sheet(isPresented: $isReselecting) {
            SelectAppsForGroupSheet(selection: reselectionBinding, customDomains: reselectionDomainsBinding)
        }
        .alert(
            schedule.isEnabled ? "Disable Schedule?" : "Enable Schedule?",
            isPresented: $showToggleConfirmation
        ) {
            Button(
                schedule.isEnabled ? "Disable" : "Enable",
                role: schedule.isEnabled ? .destructive : nil,
                action: toggleEnabled
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                schedule.isEnabled
                    ? "\(schedule.name) will stop running until you re-enable it."
                    : "\(schedule.name) will start running."
            )
        }
        .deleteConfirmation(
            title: "Delete Schedule?",
            itemName: schedule.name,
            isPresented: $showDeleteConfirmation,
            onDelete: deleteSchedule
        )
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                titleRow
                HStack(spacing: DS.Spacing.sm - 2) {
                    InlineIconText(
                        systemImage: schedule.shouldBlock ? "lock.fill" : "lock.open.fill",
                        text: schedule.shouldBlock ? "Block" : "Unblock",
                        tint: .blue
                    )
                    Text("\u{00B7}").foregroundStyle(.secondary)
                    InlineIconText(
                        systemImage: schedule.isTimed ? "hourglass" : "infinity",
                        text: schedule.isTimed ? "Timed" : "Permanent",
                        tint: .secondary
                    )
                }
            }
            Spacer()
            enabledToggle
        }
    }

    private var titleRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(schedule.name).font(.headline)
            if !schedule.isEnabled {
                Text("OFF")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs - 2)
                    .background(.red, in: Capsule())
            }
        }
    }

    private var enabledToggle: some View {
        Toggle("", isOn: enabledBinding)
            .labelsHidden()
            .tint(.accentColor)
            .disabled(isLocked)
            .accessibilityIdentifier("schedule.enabledToggle")
    }

    @ViewBuilder
    private var timingRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            if schedule.isTimed {
                Label(
                    "\(schedule.formattedStartTime) \u{2013} \(schedule.formattedEndTime)",
                    systemImage: "clock"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Label(schedule.formattedDuration, systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("Starts \(schedule.formattedStartTime)", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekdayChips: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(schedule.weekdayLabels, id: \.self) { label in
                Chip(text: label)
            }
        }
    }

    @ViewBuilder
    private var tokenStrip: some View {
        if !schedule.selection.allTokens.isEmpty || !customDomains.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                SelectionIconsView(
                    tokens: schedule.selection.allTokens,
                    customDomains: customDomains,
                    limit: 6
                )
            }
        }
    }

    private var syncWarningText: some View {
        Text("Your selection changed. Please re-select apps or domains in this schedule.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var reselectionBinding: Binding<FamilyActivitySelection> {
        Binding(
            get: { schedule.selection },
            set: { newValue in
                schedule.selection = newValue
                try? scheduleService.syncAndPersist(
                    schedule,
                    allSchedules: allSchedules,
                    screenTimeService: screenTimeService
                )
            }
        )
    }

    private var reselectionDomainsBinding: Binding<[String]> {
        Binding(
            get: { schedule.customDomains },
            set: { newValue in
                schedule.customDomains = newValue
                try? scheduleService.syncAndPersist(
                    schedule,
                    allSchedules: allSchedules,
                    screenTimeService: screenTimeService
                )
            }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { schedule.isEnabled },
            set: { _ in showToggleConfirmation = true }
        )
    }

    private func toggleEnabled() {
        do {
            try scheduleService.toggleEnabled(schedule, screenTimeService: screenTimeService)
            scheduleService.syncAllToSharedStore(allSchedules)
        } catch {
            self.error = error
        }
    }

    private func deleteSchedule() {
        scheduleService.remove(schedule, screenTimeService: screenTimeService)
        modelContext.delete(schedule)
        let remaining = allSchedules.filter { $0.id != schedule.id }
        scheduleService.syncAllToSharedStore(remaining)
    }
}
