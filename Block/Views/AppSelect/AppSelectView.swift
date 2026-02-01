import FamilyControls
import ManagedSettings
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext
    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]
    private var mainSelection: SelectedApps? {
        selectedApps.first
    }

    @State private var showSelectionChangeAlert = false
    @State private var showCategoryForbiddenAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        let blockStatus = screenTimeService.blockStatus(selection: mainSelection?.selection)
        NavigationStack {
            List {
                Section(header: Text("Selection"), footer: isSelectionEmpty(selection: mainSelection?.selection) ? Text("Note: Categories are not supported, please select individual apps and websites instead. Categories prevent custom group functionality.") : blockStatus != .none ? Text("Unblock all to modify selection") : nil) {
                    Button(isSelectionEmpty(selection: mainSelection?.selection) ? "Select Apps" : "Update Selected Apps", action: onUpdateSelectionButton)
                        .disabled(blockStatus != .none)

                    Text("\(selection.applicationTokens.count) Apps, \(selection.webDomainTokens.count) Websites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SelectionListView(selection: selection)
            }
            .navigationTitle("App Select")
            .alert("Selection will affect your groups", isPresented: $showSelectionChangeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    isFamilyActivityPickerPresented = true
                }
            } message: {
                Text("Updating your app selection will affect the functionality of your groups. After updating selection please update your groups to ensure consistency.")
            }
            .alert("Categories Not Supported", isPresented: $showCategoryForbiddenAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please select individual apps and websites. Categories prevent custom group functionality.")
            }
            .familyActivityPicker(isPresented: $isFamilyActivityPickerPresented, selection: $selection)
            .onAppear {
                if let mainSelection {
                    selection = mainSelection.selection
                }
            }
            .onChange(of: selection) { oldValue, newValue in
                if !newValue.categoryTokens.isEmpty {
                    showCategoryForbiddenAlert = true
                    selection = oldValue
                } else {
                    try? modelContext.delete(model: SelectedApps.self)

                    let newRecord = SelectedApps(selection: newValue)
                    modelContext.insert(newRecord)
                }
            }
        }
    }

    func onUpdateSelectionButton() {
        if appGroups.isEmpty {
            isFamilyActivityPickerPresented = true
        } else {
            showSelectionChangeAlert = true
        }
    }
}
