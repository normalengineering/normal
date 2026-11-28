import SwiftData
import SwiftUI

struct GroupsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)])
    private var appGroups: [AppGroup]
    @Query private var selectedApps: [SelectedApps]
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]
    @State private var isShowingSheet = false

    @State private var authAction: ProtectedAction?
    @State private var pendingGroupID: UUID?
    @State private var durationGrant: UnblockGrant?
    @State private var unblockAlert: UnblockAlert?

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var hasSelection: Bool {
        selectedApps.first?.hasItemsToBlock(customDomainsEnabled: settings.enableCustomDomains) == true
    }

    private var isEditBlocked: Bool {
        editSessionService.isEditingBlocked(
            mode: settings.editProtectionMode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount()
        )
    }

    var body: some View {
        NavigationStack {
            content
                .editProtectionBar(unblockAllMessage: BlockedMessage.groups)
                .navigationTitle("App Groups")
                .settingsToolbar()
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: openSheet) {
                            Label("Add Group", systemImage: "plus")
                        }
                        .disabled(!hasSelection || isEditBlocked)
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
            ReorderableListView(
                items: appGroups,
                rowContent: { group in
                    GroupListCardView(
                        appGroup: group,
                        authAction: $authAction,
                        pendingGroupID: $pendingGroupID,
                        durationGrant: $durationGrant,
                        unblockAlert: $unblockAlert
                    )
                },
                onMove: isEditBlocked ? nil : { move(from: $0, to: $1) }
            )
            .protectedAction(
                $authAction,
                defaultKeyType: settings.defaultKeyType(
                    for: appGroups.first { $0.id == pendingGroupID }
                ),
                keyGroupID: pendingGroupID
            )
            .sheet(item: $durationGrant) { grant in
                UnblockDurationSheet(grant: grant) { unblockAlert = UnblockAlert($0) }
            }
            .unblockAlert($unblockAlert)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        guard !isEditBlocked else { return }
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
                    .disabled(isEditBlocked)
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
        guard !isEditBlocked else { return }
        screenTimeService.ifAuthorized {
            guard !isEditBlocked else { return }
            isShowingSheet = true
        }
    }
}
