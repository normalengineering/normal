import FamilyControls
import SwiftData
import SwiftUI

struct GroupFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(EditSessionService.self) private var editSessionService

    @Query private var allGroups: [AppGroup]
    @Query private var allSettings: [Settings]
    @Query private var selectedApps: [SelectedApps]
    @Query(sort: [SortDescriptor(\Key.sortIndex)]) private var allKeys: [Key]

    let existing: AppGroup?

    @State private var groupID: UUID
    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var customDomains: [String]
    @State private var durationOverride: DefaultOverride<TimedUnblockDuration>
    @State private var keyOverride: DefaultOverride<KeyType>
    @State private var isShowingAppSelectSheet = false
    @State private var showAddKey = false
    @State private var showDeleteConfirmation = false
    @State private var didSave = false

    private var groupKeys: [Key] {
        allKeys.filter { $0.groupID == groupID }
    }

    private var durations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    private var groupKeyTypes: [KeyType] {
        let keys = Key.scoped(allKeys, toGroup: groupID)
        return KeyType.allCases.filter { type in keys.contains { $0.type == type } }
    }

    private var appDefaultDurationLabel: String {
        allSettings.first?.defaultDuration?.label ?? String(localized: "None")
    }

    private var appDefaultKeyLabel: String {
        guard let keyType = allSettings.first?.defaultKeyType, groupKeyTypes.contains(keyType) else {
            return String(localized: "None")
        }
        return keyType.label
    }

    private var isNew: Bool {
        existing == nil
    }

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: allSettings.unwrapped.editProtectionMode,
            keys: allKeys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    private var isReadOnly: Bool {
        !isNew && isEditBlocked
    }

    private var customDomainsEnabled: Bool {
        allSettings.first?.enableCustomDomains ?? false
    }

    private var availableDomains: [String] {
        selectedApps.first?.customDomains ?? []
    }

    private var storedCustomDomains: [String] {
        CustomDomains.subset(customDomains, of: availableDomains)
    }

    private var effectiveCustomDomains: [String] {
        customDomainsEnabled ? storedCustomDomains : []
    }

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return selection.count > 0 || !effectiveCustomDomains.isEmpty
    }

    init(existing: AppGroup? = nil) {
        self.existing = existing
        _groupID = State(initialValue: existing?.id ?? UUID())
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.selection ?? FamilyActivitySelection())
        _customDomains = State(initialValue: existing?.customDomains ?? [])
        _durationOverride = State(initialValue: existing?.durationOverride ?? .appDefault)
        _keyOverride = State(initialValue: existing?.keyOverride ?? .appDefault)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    if isReadOnly {
                        Text(name)
                    } else {
                        TextField("Group Name", text: $name)
                    }
                }

                Section("Apps to Block") {
                    if isReadOnly {
                        appsReadOnlyRow
                    } else {
                        Button(action: presentPicker) {
                            CountChevronRow(title: "Select Apps", count: selection.count)
                        }
                    }
                }

                if customDomainsEnabled {
                    Section {
                        CustomDomainsSubsetLink(
                            available: availableDomains,
                            selected: $customDomains,
                            isEditable: !isReadOnly
                        )
                    }
                }

                unblockingSection

                if !groupKeys.isEmpty || !isReadOnly {
                    groupKeysSection
                }

                if !isNew, !isReadOnly {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Group")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isReadOnly ? "Group" : (isNew ? "New Group" : "Edit Group"))
            .navigationBarTitleDisplayMode(.inline)
            .editProtectionBar(unblockAllMessage: BlockedMessage.groups)
            .toolbar {
                if isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: saveDefaults).fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isNew ? "Save" : "Update", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave || isEditBlocked)
                    }
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(selection: $selection)
            }
            .sheet(isPresented: $showAddKey) {
                KeyFormSheet(groupID: groupID)
            }
            .onDisappear(perform: discardStagedKeysIfNeeded)
            .deleteConfirmation(
                title: "Delete Group?",
                itemName: existing?.name ?? name,
                isPresented: $showDeleteConfirmation,
                onDelete: deleteGroup
            )
        }
    }

    private var appsReadOnlyRow: some View {
        NavigationLink {
            ViewOnlyAppsList(selection: selection)
        } label: {
            CountRow(title: "Apps", count: selection.count)
        }
    }

    private var groupKeyDeleteAction: ((IndexSet) -> Void)? {
        guard !isReadOnly else { return nil }
        return { offsets in
            guard !isEditBlocked else { return }
            for index in offsets {
                modelContext.delete(groupKeys[index])
            }
        }
    }

    private var unblockingSection: some View {
        UnblockingDefaultsSection(
            durationOverride: $durationOverride,
            keyOverride: $keyOverride,
            durations: durations,
            availableKeyTypes: groupKeyTypes,
            appDefaultDurationLabel: appDefaultDurationLabel,
            appDefaultKeyLabel: appDefaultKeyLabel,
            durationAccessibilityID: "groupForm.defaultDuration",
            keyAccessibilityID: "groupForm.defaultKey"
        )
    }

    private var groupKeysSection: some View {
        Section {
            ForEach(groupKeys) { key in
                GroupKeyRow(key: key)
            }
            .onDelete(perform: groupKeyDeleteAction)
            if !isReadOnly {
                Button {
                    showAddKey = true
                } label: {
                    Label("Add Key", systemImage: "plus")
                }
            }
        } header: {
            Text("Group Keys (Optional)")
        } footer: {
            Text("Your global keys added in the Keys tab will still work to unblock this group. Keys added here only unblock this group.")
        }
    }

    private func deleteGroup() {
        guard let existing, !isEditBlocked else { return }
        BlockActions.deleteGroup(
            existing,
            keys: allKeys,
            from: modelContext,
            timedUnblockService: timedUnblockService,
            screenTimeService: screenTimeService
        )
        dismiss()
    }

    private func discardStagedKeysIfNeeded() {
        guard isNew, !didSave else { return }
        for key in groupKeys {
            modelContext.delete(key)
        }
    }

    private func presentPicker() {
        screenTimeService.ifAuthorized { isShowingAppSelectSheet = true }
    }

    private func saveDefaults() {
        if let existing, existing.durationOverride != durationOverride || existing.keyOverride != keyOverride {
            existing.durationOverride = durationOverride
            existing.keyOverride = keyOverride
            existing.lastUpdated = .now
        }
        dismiss()
    }

    private func save() {
        guard !isEditBlocked else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        didSave = true

        if let existing {
            existing.name = trimmed
            existing.selection = selection
            existing.customDomains = storedCustomDomains
            existing.durationOverride = durationOverride
            existing.keyOverride = keyOverride
            existing.lastUpdated = .now
            timedUnblockService.updateGroupSelection(
                groupId: existing.id,
                selection: selection,
                customDomains: effectiveCustomDomains,
                screenTimeService: screenTimeService
            )
        } else {
            let nextIndex = SortIndexing.nextIndex(after: allGroups, sortIndex: \.sortIndex)
            let group = AppGroup(
                id: groupID,
                name: trimmed,
                selection: selection,
                sortIndex: nextIndex,
                customDomains: storedCustomDomains
            )
            group.durationOverride = durationOverride
            group.keyOverride = keyOverride
            modelContext.insert(group)
        }
        dismiss()
    }
}
