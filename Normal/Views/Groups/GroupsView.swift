import SwiftData
import SwiftUI

struct GroupsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var appGroups: [AppGroup]
    @Query private var selectedApps: [SelectedApps]
    @State private var isShowingSheet = false

    private var hasSelection: Bool {
        selectedApps.first?.selection.isEmpty == false
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("App Groups")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: openSheet) {
                            Label("Add Group", systemImage: "plus")
                        }
                        .disabled(!hasSelection)
                        .sheet(isPresented: $isShowingSheet) {
                            GroupFormSheet()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if appGroups.isEmpty {
            emptyState
        } else {
            ListView(items: appGroups) { group in
                GroupListCardView(appGroup: group)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if hasSelection {
            ContentUnavailableView {
                Label("No Groups", systemImage: "app.shadow")
            } description: {
                Text("Groups give you more granular control over which apps to block and unblock.")
            } actions: {
                Button("Create Group", action: openSheet)
                    .buttonStyle(.borderedProminent)
            }
        } else {
            ContentUnavailableView {
                Label("No App Selection", systemImage: "app.dashed")
            } description: {
                Text("Choose your apps in the App Select tab first. Then you can create groups for more granular control.")
            }
        }
    }

    private func openSheet() {
        screenTimeService.ifAuthorized { isShowingSheet = true }
    }
}
