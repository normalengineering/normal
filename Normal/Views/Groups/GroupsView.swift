import SwiftData
import SwiftUI

struct GroupsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @State private var isShowingSheet = false
    @Query private var appGroups: [AppGroup]
    @Query private var selectedApps: [SelectedApps]

    private var hasSelection: Bool {
        guard let selection = selectedApps.first?.selection else { return false }
        return !isSelectionEmpty(selection: selection)
    }

    var body: some View {
        NavigationStack {
            Group {
                if appGroups.isEmpty {
                    if hasSelection {
                        ContentUnavailableView {
                            Label("No Groups", systemImage: "app.shadow")
                        } description: {
                            Text("Groups give you more granular control over which apps to block and unblock.")
                        } actions: {
                            Button {
                                openSheet()
                            } label: {
                                Text("Create Group")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ContentUnavailableView {
                            Label("No App Selection", systemImage: "app.dashed")
                        } description: {
                            Text("Choose your apps in the App Select tab first. Then you can create groups for more granular control.")
                        }
                    }
                } else {
                    ListView(items: appGroups) { appGroup in
                        GroupListCardView(appGroup: appGroup)
                    }
                }
            }
            .navigationTitle("App Groups")
            .settingsToolbar()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { openSheet() }) {
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

    private func openSheet() {
        Task {
            guard await screenTimeService.ensureAuthorized() else { return }
            isShowingSheet = true
        }
    }
}
