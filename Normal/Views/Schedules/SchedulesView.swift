import SwiftData
import SwiftUI

struct SchedulesView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(ScheduleService.self) private var scheduleService
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

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasGlobalKey: Bool {
        Key.hasGlobalKey(in: keys)
    }

    private var canAdd: Bool {
        hasAppSelection && hasGlobalKey && !isBlocked
    }

    var body: some View {
        NavigationStack {
            content
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
                onMove: isBlocked ? nil : { move(from: $0, to: $1) }
            )
            .bottomFooter {
                if let message = bottomMessage {
                    FooterMessage(text: message)
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard !isBlocked else { return }
        let reordered = SortIndexing.reorder(schedules, from: source, to: destination, sortIndex: \.sortIndex)
        let constraint = selectedApps.first?.effectiveConstraint(customDomainsEnabled: settings.enableCustomDomains)
        scheduleService.syncAllToSharedStore(reordered, constrainedTo: constraint)
    }

    private var bottomMessage: LocalizedStringKey? {
        if isBlocked {
            BlockedMessage.schedules
        } else if !hasGlobalKey {
            "Add a key in the Keys tab to manage schedules."
        } else {
            nil
        }
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
        } else if isBlocked {
            ContentUnavailableView(
                "Apps Blocked",
                systemImage: "lock.fill",
                description: Text("Unblock all apps to create schedules.")
            )
        } else {
            ContentUnavailableView(
                "No Schedules",
                systemImage: "calendar.badge.clock",
                description: Text("Create a schedule to automatically block or unblock apps at set times.")
            )
        }
    }

    private func openSheet() {
        guard !isBlocked else { return }
        screenTimeService.ifAuthorized {
            guard !isBlocked else { return }
            isShowingSheet = true
        }
    }
}
