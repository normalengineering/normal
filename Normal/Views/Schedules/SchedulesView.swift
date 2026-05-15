import SwiftData
import SwiftUI

struct SchedulesView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(ScheduleService.self) private var scheduleService

    @Query(sort: [SortDescriptor(\BlockSchedule.sortIndex)])
    private var schedules: [BlockSchedule]
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]

    @State private var isShowingSheet = false

    private var hasAppSelection: Bool {
        selectedApps.first?.selection.isEmpty == false
    }

    private var isBlocked: Bool { screenTimeService.activeShieldCount() > 0 }
    private var hasKeys: Bool { !keys.isEmpty }
    private var canAdd: Bool { hasAppSelection && hasKeys && !isBlocked }

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
            ReorderableListView(items: schedules, rowContent: { schedule in
                ScheduleCardView(schedule: schedule)
            }, onMove: move)
                .safeAreaInset(edge: .bottom) {
                    if let message = bottomMessage {
                        FooterMessage(text: message)
                    }
                }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        let reordered = SortIndexing.reorder(schedules, from: source, to: destination, sortIndex: \.sortIndex)
        scheduleService.syncAllToSharedStore(reordered)
    }

    private var bottomMessage: LocalizedStringKey? {
        if isBlocked { "Unblock all apps to make schedule changes." }
        else if !hasKeys { "Add a key in the Keys tab to manage schedules." }
        else { nil }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !hasAppSelection {
            ContentUnavailableView(
                "Select Apps First",
                systemImage: "app.dashed",
                description: Text("Go to App Select to choose which apps to manage before creating schedules.")
            )
        } else if !hasKeys {
            ContentUnavailableView(
                "No Keys",
                systemImage: "key.viewfinder",
                description: Text("Add a key in the Keys tab before creating schedules.")
            )
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
        screenTimeService.ifAuthorized { isShowingSheet = true }
    }
}
