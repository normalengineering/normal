import FamilyControls
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]
    @Query private var allSettings: [Settings]

    @State private var showSelectionChangeAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var customDomains: [String] = []

    private var mainSelection: SelectedApps? { selectedApps.first }

    private var customDomainsEnabled: Bool {
        allSettings.first?.enableCustomDomains ?? false
    }

    private var effectiveCustomDomains: [String] {
        customDomainsEnabled ? customDomains : []
    }

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
                AppSelectLimitBannerView(
                    selection: selection,
                    customDomains: effectiveCustomDomains,
                    customDomainsEnabled: customDomainsEnabled
                )
                Section(header: Text("Selection"), footer: footerText) {
                    Button(buttonTitle, action: onUpdateSelectionButton)
                        .disabled(isBlocked)

                    Text(verbatim: selection.selectedTokenCounts)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if customDomainsEnabled {
                    Section(footer: Text("Select websites to block in web browsers and apps that show web content.")) {
                        NavigationLink {
                            CustomDomainsEditor(
                                domains: $customDomains,
                                otherItemCount: selection.count,
                                isEditable: !isBlocked
                            )
                        } label: {
                            CountRow(title: "Custom Domains", count: customDomains.count)
                                .opacity(isBlocked ? DS.Opacity.dim : 1)
                        }
                        .accessibilityIdentifier("appSelect.customDomainsLink")
                    }
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
                if let mainSelection {
                    selection = mainSelection.selection
                    customDomains = mainSelection.customDomains
                }
            }
            .onChange(of: selection, persistSelection)
            .onChange(of: customDomains) { _, _ in persistCustomDomains() }
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
            modelContext.insert(SelectedApps(selection: new, customDomains: customDomains))
        }
        timedUnblockService.updateMainSelection(new, customDomains: effectiveCustomDomains)
    }

    private func persistCustomDomains() {
        if let existing = mainSelection {
            existing.customDomains = customDomains
            existing.lastUpdated = .now
        } else {
            modelContext.insert(SelectedApps(selection: selection, customDomains: customDomains))
        }
        timedUnblockService.updateMainSelection(selection, customDomains: effectiveCustomDomains)
    }
}
