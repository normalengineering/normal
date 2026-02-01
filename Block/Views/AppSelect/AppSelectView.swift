import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var selectedApps: [SelectedApps]
    private var masterSelection: SelectedApps? {
        selectedApps.first
    }

    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            List {
                Section("Update Selection") {
                    Button("Update Selected Apps") {
                        isFamilyActivityPickerPresented = true
                    }
                    .disabled(masterSelection!.isBlocked)

                    Text("\(selection.applicationTokens.count) Apps, \(selection.categoryTokens.count) Categories, \(selection.webDomainTokens.count) Websites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SelectionListView(selection: selection)
            }
            .navigationTitle("App Select")
            .familyActivityPicker(isPresented: $isFamilyActivityPickerPresented, selection: $selection)
            .onAppear {
                if let masterSelection {
                    selection = masterSelection.selection
                }
            }
            .onChange(of: selection) { _, newValue in
                try? modelContext.delete(model: SelectedApps.self)

                let newRecord = SelectedApps(selection: newValue)
                modelContext.insert(newRecord)
            }
        }
    }
}
