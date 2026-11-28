import SwiftData
import SwiftUI

struct GroupKeysViewer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService

    @Query(filter: #Predicate<Key> { $0.groupID != nil }, sort: [SortDescriptor(\Key.sortIndex)])
    private var groupKeys: [Key]
    @Query private var allKeys: [Key]
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)])
    private var groups: [AppGroup]
    @Query private var allSettings: [Settings]

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: allSettings.unwrapped.editProtectionMode,
            keys: allKeys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    private var sections: [(group: AppGroup, keys: [Key])] {
        groups.compactMap { group in
            let keys = groupKeys.filter { $0.groupID == group.id }
            return keys.isEmpty ? nil : (group, keys)
        }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.group.id) { section in
                Section(section.group.name) {
                    ForEach(section.keys) { key in
                        GroupKeyRow(key: key)
                    }
                    .onDelete(perform: isEditBlocked ? nil : { offsets in delete(offsets, in: section.keys) })
                }
            }
        }
        .navigationTitle("Group Keys")
        .navigationBarTitleDisplayMode(.inline)
        .editProtectionBar(unblockAllMessage: "Unblock all apps to delete keys.")
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No Group Keys",
                    systemImage: "person.2.slash",
                    description: Text("Add group-only keys from a group's edit screen.")
                )
            }
        }
    }

    private func delete(_ offsets: IndexSet, in keys: [Key]) {
        guard !isEditBlocked else { return }
        for index in offsets {
            modelContext.delete(keys[index])
        }
    }
}
