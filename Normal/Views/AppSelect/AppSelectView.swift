import FamilyControls
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]
    @Query private var schedules: [BlockSchedule]
    @Query private var allSettings: [Settings]

    @State private var showSelectionChangeAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var customDomains: [String] = []

    private var mainSelection: SelectedApps? {
        selectedApps.first
    }

    private var customDomainsEnabled: Bool {
        allSettings.first?.enableCustomDomains ?? false
    }

    private var effectiveCustomDomains: [String] {
        customDomainsEnabled ? customDomains : []
    }

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var isAuthorized: Bool {
        screenTimeService.authorizationState == .authorized
    }

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

    private var selectionChangeWarning: SelectionChangeWarning? {
        SelectionChangeWarning(hasGroups: !appGroups.isEmpty, hasSchedules: !schedules.isEmpty)
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
                                canRemove: !isBlocked
                            )
                        } label: {
                            CountRow(title: "Custom Domains", count: customDomains.count)
                        }
                        .accessibilityIdentifier("appSelect.customDomainsLink")
                    }
                }
                SelectionListView(selection: selection)
            }
            .navigationTitle("App Select")
            .settingsToolbar()
            .alert(selectionChangeWarning?.title ?? "", isPresented: $showSelectionChangeAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Continue", role: .destructive) {
                    isFamilyActivityPickerPresented = true
                }
            } message: {
                if let selectionChangeWarning {
                    Text(selectionChangeWarning.message)
                }
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
            if selectionChangeWarning == nil {
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
        timedUnblockService.updateMainSelection(
            new,
            customDomains: effectiveCustomDomains,
            screenTimeService: screenTimeService
        )
    }

    private func persistCustomDomains() {
        if let existing = mainSelection {
            existing.customDomains = customDomains
            existing.lastUpdated = .now
        } else {
            modelContext.insert(SelectedApps(selection: selection, customDomains: customDomains))
        }
        timedUnblockService.updateMainSelection(
            selection,
            customDomains: effectiveCustomDomains,
            screenTimeService: screenTimeService
        )
    }
}

enum SelectionChangeWarning: Equatable {
    case groups
    case schedules
    case groupsAndSchedules

    init?(hasGroups: Bool, hasSchedules: Bool) {
        switch (hasGroups, hasSchedules) {
        case (true, true): self = .groupsAndSchedules
        case (true, false): self = .groups
        case (false, true): self = .schedules
        case (false, false): return nil
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .groups: "Selection may affect existing groups"
        case .schedules: "Selection may affect existing schedules"
        case .groupsAndSchedules: "Selection may affect existing groups and schedules"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .groups:
            "Groups that use apps you remove will need updating. Until then, their cards are locked."
        case .schedules:
            "Schedules that use apps you remove will need updating. Until then, their cards are locked."
        case .groupsAndSchedules:
            "Groups and schedules that use apps you remove will need updating. Until then, their cards are locked."
        }
    }
}
