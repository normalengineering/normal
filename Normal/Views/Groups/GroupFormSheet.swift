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

    let existing: AppGroup?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var customDomains: [String]
    @State private var isShowingAppSelectSheet = false
    @State private var showDeleteConfirmation = false

    private var isNew: Bool { existing == nil }

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
                    TextField("Group Name", text: $name)
                }

                Section("Apps to Block") {
                    Button(action: presentPicker) {
                        CountChevronRow(title: "Select Apps", count: selection.count)
                    }
                }

                if customDomainsEnabled {
                    CustomDomainsSubsetSection(available: availableDomains, selected: $customDomains)
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) { showDeleteConfirmation = true } label: {
                            Text("Delete Group")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Save" : "Update", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(selection: $selection)
            }
            .deleteConfirmation(
                title: "Delete Group?",
                itemName: existing?.name ?? name,
                isPresented: $showDeleteConfirmation,
                onDelete: deleteGroup
            )
        }
    }

    private func deleteGroup() {
        guard let existing else { return }
        modelContext.delete(existing)
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
