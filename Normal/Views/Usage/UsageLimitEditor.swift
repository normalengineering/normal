import FamilyControls
import SwiftData
import SwiftUI

/// What the editor is about to write. Keeps the "new" and "edit" flows on one
/// screen instead of duplicating the picker and the weekly-lock handling.
enum UsageLimitTarget: Identifiable {
    case existing(UsageLimit)
    case new

    var id: String {
        switch self {
        case let .existing(limit): limit.id.uuidString
        case .new: "new"
        }
    }

    var limit: UsageLimit? {
        if case let .existing(limit) = self {
            return limit
        }
        return nil
    }
}

struct UsageLimitEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UsageLimitService.self) private var usageLimitService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var limits: [UsageLimit]
    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]

    let target: UsageLimitTarget

    @State private var minutes: Int
    @State private var selection: FamilyActivitySelection
    @State private var isPickingApps = false
    @State private var showDeleteConfirmation = false

    private static let defaultMinutes = 60

    init(target: UsageLimitTarget) {
        self.target = target
        _minutes = State(initialValue: target.limit?.minutesPerDay ?? Self.defaultMinutes)
        _selection = State(initialValue: target.limit?.selection ?? FamilyActivitySelection())
    }

    private var existing: UsageLimit? {
        target.limit
    }

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var isTooShort: Bool {
        minutes < UsageLimit.minimumMinutes
    }

    private var hasApps: Bool {
        !selection.isEmpty
    }

    private var hasChange: Bool {
        minutes != existing?.minutesPerDay || selection != existing?.selection
    }

    /// Apps removed from what the limit meters, i.e. less is watched than before.
    private var dropsCoverage: Bool {
        guard let existing else { return false }
        return !existing.selection.isSubset(of: selection)
    }

    private var edit: UsageLimitEdit {
        guard let existing else { return .create(minutes: minutes) }
        return .adjust(from: existing.minutesPerDay, to: minutes, dropsCoverage: dropsCoverage)
    }

    private func decision(at now: Date) -> UsageLimitEditDecision {
        existing?.decide(edit, now: now) ?? .allowed(.tightening)
    }

    private func deleteDecision(at now: Date) -> UsageLimitEditDecision {
        guard let existing else { return .allowed(.tightening) }
        return existing.decide(.delete(minutes: existing.minutesPerDay), now: now)
    }

    private var duplicates: FamilyActivitySelection {
        let others = limits
            .filter { $0.id != existing?.id }
            .reduce(FamilyActivitySelection()) { $0.union($1.selection) }
        let added = existing.map { selection.subtracting($0.selection) } ?? selection
        return added.intersection(others)
    }

    private func canSave(at now: Date) -> Bool {
        hasChange && !isTooShort && hasApps && duplicates.isEmpty && decision(at: now).isAllowed
    }

    private var combinedSelection: FamilyActivitySelection {
        limits
            .filter { $0.id != existing?.id }
            .reduce(selectedApps.first?.selection ?? FamilyActivitySelection()) { $0.union($1.selection) }
            .union(selection)
    }

    var body: some View {
        NavigationStack {
            TimelineView(UsageLockSchedule(dates: existing?.lockRefreshDates ?? [])) { context in
                form(now: context.date)
            }
            .familyActivityPicker(isPresented: $isPickingApps, selection: $selection)
            .navigationTitle(existing == nil ? "New Limit" : "Edit Limit")
            .navigationBarTitleDisplayMode(.inline)
            .deleteConfirmation(
                title: "Delete Limit?",
                itemName: String(localized: "This limit"),
                isPresented: $showDeleteConfirmation,
                onDelete: delete
            )
        }
    }

    private func form(now: Date) -> some View {
        Form {
            if let notice = lockNotice(at: now) {
                lockSection(notice)
            }
            AppSelectLimitBannerView(selection: combinedSelection)
            appsSection
            timeSection
            if existing != nil {
                deleteSection(now: now)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Save" : "Update", action: save)
                    .fontWeight(.semibold)
                    .disabled(!canSave(at: now))
                    .accessibilityIdentifier("usage.save")
            }
        }
    }

    private var appsSection: some View {
        Section {
            Button { screenTimeService.ifAuthorized { isPickingApps = true } } label: {
                CountChevronRow(title: "Select Apps", count: selection.count)
            }
            .accessibilityIdentifier("usage.selectApps")

            if hasApps {
                Text(verbatim: selection.selectedTokenCounts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apps")
        } footer: {
            if duplicates.isEmpty {
                Text(
                    hasApps
                        ? "These apps, websites, and categories share one allowance."
                        : "Choose the apps, websites, or categories this limit measures."
                )
            } else {
                duplicatesWarning
            }
        }
    }

    private var duplicatesWarning: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SelectionIconsView(tokens: duplicates.allTokens, limit: 5)
            Text("Already in another limit. Remove them here, or change that limit instead.")
                .foregroundStyle(.red)
        }
        .accessibilityIdentifier("usage.duplicates")
    }

    private var timeSection: some View {
        Section {
            DurationWheelPicker(
                minutes: $minutes,
                maxMinutes: UsageLimit.maximumMinutes,
                identifierPrefix: "usage.duration"
            )
        } header: {
            Text("Time Per Day")
        } footer: {
            if isTooShort {
                Text("Limits must be at least \(UsageLimit.minimumMinutes) minutes.")
                    .foregroundStyle(.red)
            } else {
                Text(explanation)
            }
        }
    }

    private var explanation: LocalizedStringKey {
        let reset = usageLimitService.nextReset().formatted(date: .omitted, time: .shortened)
        return "After \(DurationFormat.spelled(minutes: minutes)) of combined use, these stay blocked until \(reset), even if unblocked with a key. Time already used today counts; if you're already past it, the limit starts at the next reset."
    }

    private func lockNotice(at now: Date) -> (text: Text, color: Color)? {
        guard let existing else {
            return (Text("After saving, you have 10 minutes to adjust this limit. Then raising or deleting it is allowed once every 7 days."), .blue)
        }
        switch existing.lockState(now: now) {
        case .unlocked:
            return nil
        case let .grace(until):
            return (Text("You can raise, delete, or remove apps from this limit for another \(UsageLockDeadline.countdown(to: until, now: now))."), .blue)
        case let .locked(until):
            return (Text("You can lower this limit or add apps anytime. Raising it, removing apps, or deleting it is available again \(UsageLockDeadline.phrase(until: until, now: now))."), .orange)
        }
    }

    private func lockSection(_ notice: (text: Text, color: Color)) -> some View {
        Section {
            MessageView(text: notice.text, color: notice.color)
                .standaloneListRow()
                .accessibilityIdentifier("usage.locked")
        }
    }

    private func deleteSection(now: Date) -> some View {
        Section {
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Text("Delete Limit").frame(maxWidth: .infinity)
            }
            .disabled(!deleteDecision(at: now).isAllowed)
            .accessibilityIdentifier("usage.delete")
        } footer: {
            if case let .locked(until) = deleteDecision(at: now) {
                Text("Deleting a limit loosens it. You can delete it \(UsageLockDeadline.phrase(until: until, now: now)).")
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard case let .allowed(allowance) = decision(at: .now) else { return }

        var updated = limits
        if let existing {
            existing.minutesPerDay = minutes
            existing.selection = selection
            existing.commit(allowance)
        } else {
            let limit = makeLimit()
            modelContext.insert(limit)
            // `@Query` has not refreshed yet, so fold the new limit in by hand.
            updated.append(limit)
        }

        usageLimitService.registerAll(updated, config: settings.usageLimitConfig)
        if let existing, allowance != .tightening {
            usageLimitService.clearState(for: existing)
        }
        dismiss()
    }

    private func makeLimit() -> UsageLimit {
        UsageLimit(
            selection: selection,
            minutesPerDay: minutes,
            sortIndex: SortIndexing.nextIndex(after: limits, sortIndex: \.sortIndex)
        )
    }

    private func delete() {
        guard let existing, deleteDecision(at: .now).isAllowed else { return }
        let remaining = limits.filter { $0.id != existing.id }
        modelContext.delete(existing)
        usageLimitService.registerAll(remaining, config: settings.usageLimitConfig)
        dismiss()
    }
}
