import FamilyControls
import SwiftData
import SwiftUI

struct GroupFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService

    @Query private var allGroups: [AppGroup]

    let existing: AppGroup?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var isShowingAppSelectSheet = false

    private var isNew: Bool { existing == nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && selection.count > 0
    }

    init(existing: AppGroup? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _selection = State(initialValue: existing?.selection ?? FamilyActivitySelection())
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
        }
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
            existing.lastUpdated = .now
            timedUnblockService.updateGroupSelection(groupId: existing.id, selection: selection)
        } else {
            let nextIndex = SortIndexing.nextIndex(after: allGroups, sortIndex: \.sortIndex)
            modelContext.insert(AppGroup(name: trimmed, selection: selection, sortIndex: nextIndex))
        }
        dismiss()
    }
}
