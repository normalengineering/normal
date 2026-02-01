import FamilyControls
import SwiftData
import SwiftUI

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingAppSelectSheet = false

    @State private var name: String = ""
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Group Name (e.g. Social)", text: $name)
                }

                Section("Apps to Block") {
                    Button {
                        isShowingAppSelectSheet = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                            Spacer()
                            Text("\(selectionCount(selection: selection)) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(name.isEmpty || (selection.applicationTokens.isEmpty && selection.webDomainTokens.isEmpty))
                }
            }
            .sheet(isPresented: $isShowingAppSelectSheet) {
                SelectAppsForGroupSheet(currentGroupSelection: $selection)
            }
        }
    }

    private func saveAndDismiss() {
        let newGroup = AppGroup(name: name, selection: selection)
        modelContext.insert(newGroup)
        dismiss()
    }
}
