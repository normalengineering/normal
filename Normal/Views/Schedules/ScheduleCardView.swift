import SwiftData
import SwiftUI

struct ScheduleCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var allSchedules: [BlockSchedule]
    @Query private var keys: [Key]
    @Query private var selectedApps: [SelectedApps]

    let schedule: BlockSchedule

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var showToggleConfirmation = false
    @State private var error: Error?

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasKeys: Bool { !keys.isEmpty }

    private var needsSync: Bool {
        guard let mainSelection = selectedApps.first?.selection else { return false }
        return !schedule.selection.isSubset(of: mainSelection)
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
            } else if !schedule.isEnabled && !isLocked {
                offHintText
            }
        }
        .opacity((schedule.isEnabled && !isLocked) ? 1 : DS.Opacity.dim)
        .onTapGesture { if !isLocked || needsSync { isEditing = true } }
        .editDeleteContextMenu(
            isDisabled: isLocked && !needsSync,
            onEdit: { isEditing = true },
            onDelete: { showDeleteConfirmation = true }
        )
        .sheet(isPresented: $isEditing) {
            ScheduleFormSheet(existing: schedule)
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
                Text(schedule.name).font(.headline)
                HStack(spacing: DS.Spacing.sm - 2) {
                    InlineIconText(
                        systemImage: schedule.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                        text: schedule.isEnabled ? "On" : "Off",
                        tint: schedule.isEnabled ? .green : .secondary
                    )
                    Text("\u{00B7}").foregroundStyle(.secondary)
                    InlineIconText(
                        systemImage: schedule.shouldBlock ? "lock.fill" : "lock.open.fill",
                        text: schedule.shouldBlock ? "Block" : "Unblock",
                        tint: schedule.shouldBlock ? .red : .green
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
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
                .tint(.accentColor)
                .disabled(isLocked)
        }
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
        if !schedule.selection.allTokens.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                SelectionIconsView(tokens: schedule.selection.allTokens)
            }
        }
    }

    private var syncWarningText: some View {
        Text("App selection changed. Please re-select apps in this schedule.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var offHintText: some View {
        Text("Toggle on to start running this schedule.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
