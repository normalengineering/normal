import FamilyControls
import SwiftData
import SwiftUI

struct GroupFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existing: AppGroup?

    @State private var name: String
    @State private var selection: FamilyActivitySelection
    @State private var isShowingAppSelectSheet = false

    private var isNew: Bool { existing == nil }

    private var totalSelected: Int {
        selectionCount(selection: selection)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && totalSelected > 0
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
                    Button {
                        isShowingAppSelectSheet = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                                .foregroundStyle(.primary)
                            Spacer()
                            if totalSelected > 0 {
                                Text("\(totalSelected)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
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
                    Button(isNew ? "Save" : "Update") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(selection: $selection)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing {
            existing.name = trimmed
            existing.selection = selection
            existing.lastUpdated = .now
        } else {
            modelContext.insert(AppGroup(name: trimmed, selection: selection))
        }

        dismiss()
    }
}
