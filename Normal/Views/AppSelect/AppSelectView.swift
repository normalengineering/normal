import FamilyControls
import SwiftData
import SwiftUI

struct AppSelectView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(\.modelContext) private var modelContext

    @Query private var selectedApps: [SelectedApps]
    @Query private var appGroups: [AppGroup]
    @Query private var schedules: [BlockSchedule]
    @Query private var allSettings: [Settings]

    @State private var showSelectionChangeAlert = false
    @State private var isFamilyActivityPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var customDomains: [String] = []
    @State private var hasLoaded = false

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var mainSelection: SelectedApps? {
        selectedApps.first
    }

    private var customDomainsEnabled: Bool {
        settings.enableCustomDomains
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
                    guard !isBlocked else { return }
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
                hasLoaded = true
            }
            .onChange(of: selection, persistSelection)
            .onChange(of: customDomains) { oldValue, newValue in
                persistCustomDomains(from: oldValue, to: newValue)
            }
        }
    }

    private func onUpdateSelectionButton() {
        guard !isBlocked else { return }
        screenTimeService.ifAuthorized {
            guard !isBlocked else { return }
            if selectionChangeWarning == nil {
                isFamilyActivityPickerPresented = true
            } else {
                showSelectionChangeAlert = true
            }
        }
    }

    private func persistSelection(_: FamilyActivitySelection, _ new: FamilyActivitySelection) {
        guard hasLoaded else { return }
        let storedSelection = mainSelection?.selection ?? FamilyActivitySelection()
        guard new != storedSelection else { return }
        guard !isBlocked else {
            selection = storedSelection
            return
        }
        let storedDomains = mainSelection?.customDomains ?? []
        let nextDomains = mainSelection?.customDomains ?? customDomains
        if let existing = mainSelection {
            existing.selection = new
            existing.lastUpdated = .now
        } else {
            modelContext.insert(SelectedApps(selection: new, customDomains: nextDomains))
        }
        BlockActions.updateMainSelection(
            from: storedSelection,
            oldCustomDomains: storedDomains,
            to: new,
            newCustomDomains: nextDomains,
            schedules: schedules,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService,
            scheduleService: scheduleService
        )
    }

    private func persistCustomDomains(from _: [String], to new: [String]) {
        guard hasLoaded else { return }
        let storedDomains = mainSelection?.customDomains ?? []
        guard new != storedDomains else { return }
        if isBlocked {
            let storedSet = Set(storedDomains.compactMap(DomainNormalizer.normalize))
            let newSet = Set(new.compactMap(DomainNormalizer.normalize))
            guard storedSet.isSubset(of: newSet) else {
                customDomains = storedDomains
                return
            }
        }
        let storedSelection = mainSelection?.selection ?? selection
        if let existing = mainSelection {
            existing.customDomains = new
            existing.lastUpdated = .now
        } else {
            modelContext.insert(SelectedApps(selection: storedSelection, customDomains: new))
        }
        BlockActions.updateMainSelection(
            from: storedSelection,
            oldCustomDomains: storedDomains,
            to: storedSelection,
            newCustomDomains: new,
            schedules: schedules,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService,
            scheduleService: scheduleService
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
