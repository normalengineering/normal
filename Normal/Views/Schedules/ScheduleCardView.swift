import FamilyControls
import SwiftData
import SwiftUI

struct ScheduleCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query private var allSchedules: [BlockSchedule]
    @Query private var keys: [Key]
    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]

    let schedule: BlockSchedule

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var customDomains: [String] {
        settings.enableCustomDomains ? schedule.customDomains : []
    }

    @State private var isEditing = false
    @State private var isReselecting = false
    @State private var showDeleteConfirmation = false
    @State private var showToggleConfirmation = false
    @State private var error: Error?

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: settings.editProtectionMode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    private var hasGlobalKey: Bool {
        Key.hasGlobalKey(in: keys)
    }

    private var needsSync: Bool {
        guard let main = selectedApps.first else { return false }
        if !schedule.selection.isSubset(of: main.selection) {
            return true
        }
        if settings.enableCustomDomains,
            CustomDomains.needsResync(schedule.customDomains, main: main.customDomains)
        {
            return true
        }
        return false
    }

    private var isLocked: Bool {
        isEditBlocked || !hasGlobalKey || needsSync
    }

    private var mainSelectionConstraint: (selection: FamilyActivitySelection, customDomains: [String])? {
        guard let main = selectedApps.first else { return nil }
        return (selection: main.selection, customDomains: settings.enableCustomDomains ? main.customDomains : [])
    }

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
            if needsSync, !isEditBlocked, hasGlobalKey {
                isReselecting = true
            } else if !isLocked || isEditBlocked {
                isEditing = true
            }
        }
        .editDeleteContextMenu(
            isDisabled: isEditBlocked || !hasGlobalKey,
            isDuplicateDisabled: needsSync || isEditBlocked || !hasGlobalKey,
            onEdit: {
                if needsSync, !isEditBlocked, hasGlobalKey {
                    isReselecting = true
                } else {
                    isEditing = true
                }
            },
            onDuplicate: duplicateSchedule,
            onDelete: { showDeleteConfirmation = true }
        )
        .sheet(isPresented: $isEditing) {
            ScheduleFormSheet(existing: schedule)
        }
        .sheet(isPresented: $isReselecting) {
            SelectAppsForGroupSheet(
                selection: .constant(schedule.selection),
                customDomains: .constant(schedule.customDomains)
            ) { newSelection, newDomains in
                guard !isEditBlocked, hasGlobalKey else { return }
                schedule.selection = newSelection
                schedule.customDomains = newDomains
                do {
                    try scheduleService.syncAndPersist(
                        schedule,
                        allSchedules: allSchedules,
                        screenTimeService: screenTimeService,
                        constrainedTo: mainSelectionConstraint
                    )
                } catch {
                    self.error = error
                }
            }
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
        .alert(
            "Schedule Notice",
            isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })
        ) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
        .deleteConfirmation(
            title: "Delete Schedule?",
            itemName: schedule.name,
            isPresented: $showDeleteConfirmation,
            onDelete: deleteSchedule
        )
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .top) {
                    titleRow
                    Spacer()
                    enabledToggle
                }
                modeRow
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    titleRow
                    modeRow
                }
                Spacer()
                enabledToggle
            }
        }
    }

    private var modeRow: some View {
        AdaptiveStack(spacing: DS.Spacing.sm - 2) {
            InlineIconText(
                systemImage: schedule.shouldBlock ? "lock.fill" : "lock.open.fill",
                text: schedule.shouldBlock ? "Block" : "Unblock",
                tint: .blue
            )
            if !dynamicTypeSize.isAccessibilitySize {
                Text("\u{00B7}").foregroundStyle(.secondary)
            }
            InlineIconText(
                systemImage: schedule.isTimed ? "hourglass" : "infinity",
                text: schedule.isTimed ? "Timed" : "Permanent",
                tint: .secondary
            )
        }
    }

    private var titleRow: some View {
        AdaptiveStack(spacing: DS.Spacing.sm) {
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

    private var timingRow: some View {
        AdaptiveStack(spacing: dynamicTypeSize.isAccessibilitySize ? DS.Spacing.xs : DS.Spacing.lg) {
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(schedule.weekdayLabels, id: \.self) { label in
                    Chip(text: label)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("schedule.weekdayChips")

            WeekdayStrip(weekdays: schedule.weekdays)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .accessibilityIdentifier("schedule.weekdayStrip")
        }
    }

    @ViewBuilder
    private var tokenStrip: some View {
        if !schedule.selection.allTokens.isEmpty || !customDomains.isEmpty {
            SelectionIconRow(
                tokens: schedule.selection.allTokens,
                customDomains: customDomains,
                maxCount: 6
            )
        }
    }

    private var syncWarningText: some View {
        Text("Your selection changed. Please re-select apps or domains in this schedule.")
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
        guard !isEditBlocked, hasGlobalKey else { return }
        do {
            try scheduleService.toggleEnabled(
                schedule,
                allSchedules: allSchedules,
                screenTimeService: screenTimeService,
                constrainedTo: mainSelectionConstraint
            )
        } catch {
            self.error = error
        }
    }

    private func duplicateSchedule() {
        guard !isEditBlocked, hasGlobalKey, !needsSync else { return }
        let ordered = allSchedules.sorted { $0.sortIndex < $1.sortIndex }
        let copy = schedule.duplicate(named: CopyNaming.name(for: schedule.name, existing: allSchedules.map(\.name)))
        withAnimation {
            modelContext.insert(copy)
            let reordered = SortIndexing.insert(copy, after: schedule, in: ordered, sortIndex: \.sortIndex)
            scheduleService.syncAllToSharedStore(reordered, constrainedTo: mainSelectionConstraint)
        }
    }

    private func deleteSchedule() {
        guard !isEditBlocked, hasGlobalKey else { return }
        let remaining = allSchedules.filter { $0.id != schedule.id }
        scheduleService.remove(
            schedule,
            remaining: remaining,
            screenTimeService: screenTimeService,
            constrainedTo: mainSelectionConstraint
        )
        modelContext.delete(schedule)
    }
}
