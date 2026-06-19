import FamilyControls
import SwiftData
import SwiftUI

struct GroupFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService

    @Query private var allGroups: [AppGroup]
    @Query private var allSettings: [Settings]
    @Query private var selectedApps: [SelectedApps]
    @Query(sort: [SortDescriptor(\Key.sortIndex)]) private var allKeys: [Key]

    let existing: AppGroup?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var customDomains: [String]
    @State private var isShowingAppSelectSheet = false
    @State private var showAddKey = false
    @State private var showDeleteConfirmation = false

    private var groupKeys: [Key] {
        guard let existing else { return [] }
        return allKeys.filter { $0.groupID == existing.id }
    }

    private var isNew: Bool { existing == nil }

    private var isReadOnly: Bool { !isNew && screenTimeService.activeShieldCount() > 0 }

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
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.selection ?? FamilyActivitySelection())
        _customDomains = State(initialValue: existing?.customDomains ?? [])
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

                if !isNew, !groupKeys.isEmpty || !isReadOnly { groupKeysSection }

                if !isNew, !isReadOnly {
                    Section {
                        Button(role: .destructive) { showDeleteConfirmation = true } label: {
                            Text("Delete Group")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isReadOnly ? "Group" : (isNew ? "New Group" : "Edit Group"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isReadOnly {
                    FooterMessage(text: BlockedMessage.groups)
                }
            }
            .toolbar {
                if isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.fontWeight(.semibold)
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isNew ? "Save" : "Update", action: save)
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(selection: $selection)
            }
            .sheet(isPresented: $showAddKey) {
                if let existing { KeyFormSheet(groupID: existing.id) }
            }
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
            for index in offsets {
                modelContext.delete(groupKeys[index])
            }
        }
    }

    private var groupKeysSection: some View {
        Section {
            ForEach(groupKeys) { key in
                GroupKeyRow(key: key)
            }
            .onDelete(perform: groupKeyDeleteAction)
            if !isReadOnly {
                Button { showAddKey = true } label: {
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
        guard let existing else { return }
        existing.deleteCascading(keys: allKeys, from: modelContext)
        dismiss()
    }

    private func presentPicker() {
        screenTimeService.ifAuthorized { isShowingAppSelectSheet = true }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
            existing.selection = selection
            existing.customDomains = storedCustomDomains
            existing.lastUpdated = .now
            timedUnblockService.updateGroupSelection(
                groupId: existing.id,
                selection: selection,
                customDomains: effectiveCustomDomains
            )
        } else {
            let nextIndex = SortIndexing.nextIndex(after: allGroups, sortIndex: \.sortIndex)
            modelContext.insert(AppGroup(
                name: trimmed,
                selection: selection,
                sortIndex: nextIndex,
                customDomains: storedCustomDomains
            ))
        }
        dismiss()
    }
}
