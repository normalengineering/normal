import SwiftData
import SwiftUI

private struct WidgetActionResponder: ViewModifier {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)]) private var groups: [AppGroup]
    @Query private var keys: [Key]

    let coordinator: NavigationCoordinator
    @Binding var selectedTab: AppTab

    @State private var authAction: (@MainActor () -> Void)?
    @State private var actionGroup: AppGroup?
    @State private var keyType: KeyType?
    @State private var allowBypass = false
    @State private var showDurationSheet = false

    private var availableKeyTypes: [KeyType] {
        KeyType.selectable(registered: keys.map(\.type))
    }

    func body(content: Content) -> some View {
        content
            .protectedAction($authAction, allowBypass: allowBypass, defaultKeyType: keyType)
            .sheet(isPresented: $showDurationSheet) {
                if let actionGroup { GroupTimedUnblockSheet(group: actionGroup) }
            }
            .onOpenURL { coordinator.handle(url: $0) }
            .onChange(of: coordinator.pendingGroupAction) { _, request in resolve(request) }
            .onChange(of: groups) { _, _ in syncWidget() }
            .onChange(of: keys) { _, _ in syncWidget() }
            .onChange(of: screenTimeService.lastUpdate) { _, _ in syncWidget() }
            .onAppear { syncWidget() }
    }

    private func syncWidget() {
        let blockStatuses = Dictionary(uniqueKeysWithValues: groups.map { group in
            (group.id.uuidString, screenTimeService.blockStatus(selection: group.selection).widget.rawValue)
        })
        WidgetSync.sync(
            groups: groups,
            availableKeyTypes: availableKeyTypes,
            blockStatuses: blockStatuses
        )
    }

    private func resolve(_ request: GroupActionRequest?) {
        guard let request,
              allSettings.first?.hasCompletedOnboarding == true,
              let group = groups.first(where: { $0.id == request.groupID })
        else {
            coordinator.clearPendingGroupAction()
            return
        }
        selectedTab = .groups
        actionGroup = group

        switch request.action {
        case let .unlock(duration, requestedKeyType):
            keyType = requestedKeyType
            allowBypass = false
            authAction = { unlock(group, duration: duration) }
        case .block:
            keyType = nil
            allowBypass = true
            authAction = { block(group) }
        }

        coordinator.clearPendingGroupAction()
    }

    private func unlock(_ group: AppGroup, duration: UnblockDuration?) {
        if let duration {
            try? timedUnblockService.startGroup(
                duration: duration,
                groupId: group.id,
                selection: group.selection,
                screenTimeService: screenTimeService
            )
        } else {
            showDurationSheet = true
        }
    }

    private func block(_ group: AppGroup) {
        if timedUnblockService.isGroupUnblockActive(groupId: group.id) {
            timedUnblockService.cancelGroup(
                groupId: group.id,
                selection: group.selection,
                screenTimeService: screenTimeService
            )
        } else {
            screenTimeService.addToShields(selection: group.selection)
        }
    }
}

extension View {
    func widgetActionResponder(
        coordinator: NavigationCoordinator,
        selectedTab: Binding<AppTab>
    ) -> some View {
        modifier(WidgetActionResponder(coordinator: coordinator, selectedTab: selectedTab))
    }
}
