import SwiftData
import SwiftUI

struct SchedulesView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(ScheduleService.self) private var scheduleService
    @Environment(EditSessionService.self) private var editSessionService
    @Environment(\.navigationCoordinator) private var navigation

    @Query(sort: [SortDescriptor(\BlockSchedule.sortIndex)])
    private var schedules: [BlockSchedule]
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]

    @State private var isShowingSheet = false

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var hasAppSelection: Bool {
        selectedApps.first?.hasItemsToBlock(customDomainsEnabled: settings.enableCustomDomains) == true
    }

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: settings.editProtectionMode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    private var hasGlobalKey: Bool {
        Key.hasGlobalKey(in: keys)
    }

    private var canAdd: Bool {
        hasAppSelection && hasGlobalKey && !isEditBlocked
    }

    var body: some View {
        NavigationStack {
            content
                .editProtectionBar(unblockAllMessage: BlockedMessage.schedules) {
                    if !schedules.isEmpty, !hasGlobalKey {
                        FooterMessage(text: "Add a key in the Keys tab to manage schedules.")
                    }
                }
                .navigationTitle("Schedules")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: openSheet) {
                            Label("Add Schedule", systemImage: "plus")
                        }
                        .disabled(!canAdd)
                        .sheet(isPresented: $isShowingSheet) {
                            ScheduleFormSheet()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if schedules.isEmpty {
            emptyState
        } else {
            ReorderableListView(
                items: schedules,
                rowContent: { schedule in
                    ScheduleCardView(schedule: schedule)
                },
                onMove: isEditBlocked ? nil : { move(from: $0, to: $1) }
            )
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard !isEditBlocked else { return }
        let reordered = SortIndexing.reorder(schedules, from: source, to: destination, sortIndex: \.sortIndex)
        let constraint = selectedApps.first.map { main in
            (selection: main.selection, customDomains: settings.enableCustomDomains ? main.customDomains : [])
        }
        scheduleService.syncAllToSharedStore(reordered, constrainedTo: constraint)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !hasAppSelection {
            ContentUnavailableView(
                "Select Apps First",
                systemImage: "app.dashed",
                description: Text("Go to App Select to choose which apps to manage before creating schedules.")
            )
        } else if !hasGlobalKey {
            ContentUnavailableView {
                Label("No Keys", systemImage: "key.viewfinder")
            } description: {
                Text("Add a key in the Keys tab before creating schedules.")
            } actions: {
                Button("Go to Keys") { navigation.show(.keys) }
                    .buttonStyle(.borderedProminent)
            }
        } else if isEditBlocked {
            if settings.editProtectionMode == .requireKey, EditSessionService.hasUsableGlobalKey(in: keys) {
                ContentUnavailableView(
                    "Editing Blocked",
                    systemImage: "lock.fill",
                    description: Text("Unblock editing with a key to create schedules.")
                )
            } else {
                ContentUnavailableView(
                    "Apps Blocked",
                    systemImage: "lock.fill",
                    description: Text("Unblock all apps to create schedules.")
                )
            }
        } else {
            ContentUnavailableView(
                "No Schedules",
                systemImage: "calendar.badge.clock",
                description: Text("Create a schedule to automatically block or unblock apps at set times.")
            )
        }
    }

    private func openSheet() {
        guard !isEditBlocked else { return }
        screenTimeService.ifAuthorized {
            guard !isEditBlocked else { return }
            isShowingSheet = true
        }
    }
}
