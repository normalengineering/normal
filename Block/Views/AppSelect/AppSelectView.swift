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
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var footerText: Text? {
        if isBlocked {
            Text("Unblock all apps to edit selection.")
        } else if isSelectionEmpty(selection: mainSelection?.selection) {
            Text("Selecting individual apps is recommended over categories for more granular control.")
        } else {
            nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Selection"), footer: footerText) {
                    Button(isSelectionEmpty(selection: mainSelection?.selection) ? "Select Apps" : "Update Selected Apps", action: onUpdateSelectionButton)
                        .disabled(isBlocked)

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
            .familyActivityPicker(isPresented: $isFamilyActivityPickerPresented, selection: $selection)
            .onAppear {
                if let mainSelection {
                    selection = mainSelection.selection
                }
            }
            .onChange(of: selection) { _, newValue in
                if let existing = mainSelection {
                    existing.selection = newValue
                    existing.lastUpdated = .now
                } else {
                    modelContext.insert(SelectedApps(selection: newValue))
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
