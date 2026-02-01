import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]
    private var masterSelection: SelectedApps? {
        selectedApps.first
    }

    @State private var showSelectionChangeAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        NavigationStack {
            List {
                Section("Update Selection") {
                    Button("Update Selected Apps", action: onUpdateSelectionButton)
                    .disabled(masterSelection?.isBlocked ?? false)

                    Text("\(selection.applicationTokens.count) Apps, \(selection.categoryTokens.count) Categories, \(selection.webDomainTokens.count) Websites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SelectionListView(selection: selection)
            }
            .navigationTitle("App Select")
            .alert(isPresented: $showSelectionChangeAlert) {
                Alert(
                    title: Text("Selection will affect your groups"),
                    message: Text("Updating your app selection will affect the functionality of your groups. After updating selection please update your groups to ensure group functionality."),
                    primaryButton: .cancel(Text("Cancel")) {
                        showSelectionChangeAlert = false
                    },
                    secondaryButton: .destructive(Text("Continue")) {
                        isFamilyActivityPickerPresented = true
                    }
                )
            }
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
    
    func onUpdateSelectionButton(){
        if appGroups.isEmpty {
            isFamilyActivityPickerPresented = true
        }
        else {
            showSelectionChangeAlert = true
        }
    }
}

