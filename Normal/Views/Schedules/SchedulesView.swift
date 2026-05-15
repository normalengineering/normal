import SwiftData
import SwiftUI

struct SchedulesView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    @Query(sort: [SortDescriptor(\BlockSchedule.startHour), SortDescriptor(\BlockSchedule.startMinute)])
    private var schedules: [BlockSchedule]
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]

    @State private var isShowingSheet = false

    private var hasAppSelection: Bool {
        guard let main = selectedApps.first else { return false }
        return !isSelectionEmpty(selection: main.selection)
    }

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasKeys: Bool {
        !keys.isEmpty
    }

    private var canAdd: Bool {
        hasAppSelection && hasKeys && !isBlocked
    }

    var body: some View {
        NavigationStack {
            Group {
                if schedules.isEmpty {
                    emptyState
                } else {
                    ListView(items: schedules) { schedule in
                        ScheduleCardView(schedule: schedule)
                    }
                    .safeAreaInset(edge: .bottom) {
                        if isBlocked {
                            footerMessage("Unblock all apps to make schedule changes.")
                        } else if !hasKeys {
                            footerMessage("Add a key in the Keys tab to manage schedules.")
                        }
                    }
                }
            }
            .navigationTitle("Schedules")
            .settingsToolbar()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { openSheet() } label: {
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

    private func openSheet() {
        Task {
            guard await screenTimeService.ensureAuthorized() else { return }
            isShowingSheet = true
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

    private func footerMessage(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }
}
