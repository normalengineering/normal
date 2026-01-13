import FamilyControls
import SwiftData
import SwiftUI

struct CreateAppGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isFamilyActivityPickerPresented = false

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
                        isFamilyActivityPickerPresented = true
                    } label: {
                        HStack {
                            Text("Select Apps")
                            Spacer()
                            Text("\(selection.applicationTokens.count + selection.categoryTokens.count) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $isFamilyActivityPickerPresented, selection: $selection)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(name.isEmpty || (selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty))
                }
            }
        }
    }

    private func saveAndDismiss() {
        let newGroup = AppGroup(name: name, selection: selection)
        modelContext.insert(newGroup)
        dismiss()
    }
}
