import FamilyControls
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]

    @State private var showSelectionChangeAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    private var mainSelection: SelectedApps? { selectedApps.first }

    private var isBlocked: Bool { screenTimeService.activeShieldCount() > 0 }
    private var isAuthorized: Bool { screenTimeService.authorizationState == .authorized }

    private var footerText: Text? {
        if !isAuthorized {
            Text("Screen Time permission is required to select apps.")
        } else if isBlocked {
            Text("Unblock all apps to edit selection.")
        } else if mainSelection?.selection.isEmpty ?? true {
            Text("Selecting individual apps is recommended over categories for more granular control.")
        } else {
            nil
        }
    }

    private var buttonTitle: LocalizedStringKey {
        (mainSelection?.selection.isEmpty ?? true) ? "Select Apps" : "Update Selected Apps"
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Selection"), footer: footerText) {
                    Button(buttonTitle, action: onUpdateSelectionButton)
                        .disabled(isBlocked)

                    Text("\(selection.applicationTokens.count) Apps, \(selection.webDomainTokens.count) Websites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                SelectionListView(selection: selection)
            }
            .navigationTitle("App Select")
            .settingsToolbar()
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
                if let mainSelection { selection = mainSelection.selection }
            }
            .onChange(of: selection, persistSelection)
        }
    }

    private func onUpdateSelectionButton() {
        screenTimeService.ifAuthorized {
            if appGroups.isEmpty {
                isFamilyActivityPickerPresented = true
            } else {
                showSelectionChangeAlert = true
            }
        }
    }

    private func persistSelection(_: FamilyActivitySelection, _ new: FamilyActivitySelection) {
        if let existing = mainSelection {
            existing.selection = new
            existing.lastUpdated = .now
        } else {
            modelContext.insert(SelectedApps(selection: new))
        }
        timedUnblockService.updateMainSelection(new)
    }
}
