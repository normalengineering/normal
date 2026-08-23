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
        if case let .existing(limit) = self { return limit }
        return nil
    }
}

struct UsageLimitEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UsageLimitService.self) private var usageLimitService
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query private var limits: [UsageLimit]
    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]

    let target: UsageLimitTarget

    /// Closes the whole presentation. `dismiss()` alone only pops when this is
    /// pushed behind the app picker.
    let onFinish: () -> Void

    @State private var minutes: Int
    @State private var selection: FamilyActivitySelection
    @State private var isPickingApps = false
    @State private var showDeleteConfirmation = false

    private static let defaultMinutes = 60

    init(target: UsageLimitTarget, onFinish: @escaping () -> Void) {
        self.target = target
        self.onFinish = onFinish
        _minutes = State(initialValue: target.limit?.minutesPerDay ?? Self.defaultMinutes)

        _selection = State(initialValue: target.limit?.selection ?? FamilyActivitySelection())
    }

    private var existing: UsageLimit? { target.limit }
    private var settings: Settings { allSettings.unwrapped }

    private var isTooShort: Bool { minutes < UsageLimit.minimumMinutes }

    private var hasApps: Bool { !selection.isEmpty }

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

    private var decision: UsageLimitEditDecision { usageLimitService.decide(edit) }

    private var deleteDecision: UsageLimitEditDecision {
        guard let existing else { return .allowed(.tightening) }
        return usageLimitService.decide(.delete(minutes: existing.minutesPerDay))
    }

    private var canSave: Bool { hasChange && !isTooShort && hasApps && decision.isAllowed }

    var body: some View {
        Form {
            AppSelectLimitBannerView(selection: selection)
            appsSection
            pickerSection
            if let locked = lockedMessage { lockSection(locked) }
            if existing != nil { deleteSection }
        }
        .familyActivityPicker(isPresented: $isPickingApps, selection: $selection)

        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onFinish)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existing == nil ? "Set Limit" : "Update", action: save)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("usage.save")
            }
        }
        .deleteConfirmation(
            title: "Remove Limit?",
            itemName: title,
            isPresented: $showDeleteConfirmation,
            onDelete: delete
        )
    }

    private var title: String {
        existing == nil ? String(localized: "New Limit") : String(localized: "App Limit")
    }

    /// Apple's system picker, so a limit can cover anything on the device
    /// rather than only what is already in the blocked selection.
    private var appsSection: some View {
        Section {
            Button { screenTimeService.ifAuthorized { isPickingApps = true } } label: {
                CountChevronRow(title: "Select Apps", count: selection.count)
            }
            .accessibilityIdentifier("usage.selectApps")

            Text(verbatim: selection.selectedTokenCounts)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Apps")
        } footer: {
            Text(
                hasApps
                    ? "These apps share the allowance below, and lock again once it runs out."
                    : "Choose the apps this limit measures."
            )
        }
    }

    private var pickerSection: some View {
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
        "After \(DurationFormat.spelled(minutes: minutes)) of combined use, these apps lock again for the rest of the day, even while everything else is unblocked. Resets at midnight — unused time does not carry over."
    }

    /// The user is trying to loosen a limit and the weekly cooldown has not elapsed.
    private var lockedMessage: String? {
        guard hasChange, case let .locked(until) = decision else { return nil }
        let when = until.formatted(date: .abbreviated, time: .shortened)
        return dropsCoverage
            ? String(localized: "Removing apps from a limit loosens it. You can change this again on \(when).")
            : String(localized: "You can raise this limit again on \(when).")
    }

    private func lockSection(_ message: String) -> some View {
        Section {
            MessageView(message: message, color: .orange)
                .accessibilityIdentifier("usage.locked")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                Text("Remove Limit").frame(maxWidth: .infinity)
            }
            .disabled(!deleteDecision.isAllowed)
            .accessibilityIdentifier("usage.remove")
        } footer: {
            if case let .locked(until) = deleteDecision {
                Text("Removing a limit loosens it, so it waits for the same weekly reset on \(until.formatted(date: .abbreviated, time: .shortened)).")
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard case let .allowed(allowance) = decision else { return }

        var updated = limits
        if let existing {
            existing.minutesPerDay = minutes
            existing.selection = selection
            // A raised ceiling should take effect today, not after midnight.
            if allowance != .tightening {
                usageLimitService.clearState(for: existing, screenTimeService: screenTimeService)
            }
        } else {
            let limit = makeLimit()
            modelContext.insert(limit)
            // `@Query` has not refreshed yet, so fold the new limit in by hand.
            updated.append(limit)
        }

        usageLimitService.commit(allowance)
        reregister(updated)
        onFinish()
    }

    private func makeLimit() -> UsageLimit {
        UsageLimit(
            selection: selection,
            minutesPerDay: minutes,
            sortIndex: SortIndexing.nextIndex(after: limits, sortIndex: \.sortIndex)
        )
    }

    private func delete() {
        guard let existing, case let .allowed(allowance) = deleteDecision else { return }
        let remaining = limits.filter { $0.id != existing.id }
        modelContext.delete(existing)
        usageLimitService.commit(allowance)
        reregister(remaining)
        onFinish()
    }

    private func reregister(_ updated: [UsageLimit]) {
        usageLimitService.registerAll(updated)
        screenTimeService.notifyUpdate()
    }
}
