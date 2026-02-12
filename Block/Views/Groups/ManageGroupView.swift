import FamilyControls
import SwiftData
import SwiftUI

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var selection = FamilyActivitySelection()
    @State private var isShowingAppSelectSheet = false

    private var totalSelected: Int {
        selectionCount(selection: selection)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
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
                } header: {
                    Text("Apps to Block")
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || totalSelected <= 0)
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(selection: $selection)
            }
        }
    }

    private func saveAndDismiss() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newGroup = AppGroup(name: trimmed, selection: selection)
        modelContext.insert(newGroup)
        dismiss()
    }
}
