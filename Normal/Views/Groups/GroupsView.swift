import SwiftData
import SwiftUI

struct GroupsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)])
    private var appGroups: [AppGroup]
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]
    @Query private var allSettings: [Settings]
    @State private var isShowingSheet = false

    @State private var authAction: (@MainActor () -> Void)?
    @State private var allowBypass = false
    @State private var pendingGroupID: UUID?
    @State private var pendingDurationGroup: AppGroup?

    private var hasSelection: Bool {
        selectedApps.first?.selection.isEmpty == false
    }

    private var isBlocked: Bool {
        screenTimeService.activeShieldCount() > 0
    }

    private var hasGlobalKey: Bool { Key.hasGlobalKey(in: keys) }

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
                        .disabled(!hasSelection || isBlocked)
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
            ReorderableListView(items: appGroups, rowContent: { group in
                GroupListCardView(
                    appGroup: group,
                    authAction: $authAction,
                    allowBypass: $allowBypass,
                    pendingGroupID: $pendingGroupID,
                    pendingDurationGroup: $pendingDurationGroup
                )
            }, onMove: move)
                .safeAreaInset(edge: .bottom) {
                    if isBlocked {
                        FooterMessage(text: BlockedMessage.groups)
                    } else if !hasGlobalKey {
                        FooterMessage(text: "Add a key in the Keys tab before blocking groups.")
                    }
                }
                // Host the key prompt on the stable list, scoped to whichever card
                // triggered it, instead of on the card row.
                .protectedAction(
                    $authAction,
                    allowBypass: allowBypass,
                    defaultKeyType: allSettings.unwrapped.defaultKeyType,
                    keyGroupID: pendingGroupID
                )
                .sheet(item: $pendingDurationGroup) { group in
                    GroupTimedUnblockSheet(group: group)
                }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        _ = SortIndexing.reorder(appGroups, from: source, to: destination, sortIndex: \.sortIndex)
    }

    @ViewBuilder
    private var emptyState: some View {
        if hasSelection {
            ContentUnavailableView {
                Label("No Groups", systemImage: AppIcons.groups)
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
