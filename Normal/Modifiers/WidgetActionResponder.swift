import AppIntents
import SwiftData
import SwiftUI

private struct WidgetActionResponder: ViewModifier {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(UnlockRequestInbox.self) private var unlockInbox
    @Environment(\.scenePhase) private var scenePhase
    @Query private var allSettings: [Settings]
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)]) private var groups: [AppGroup]
    @Query private var keys: [Key]
    @Query private var selectedApps: [SelectedApps]

    let coordinator: NavigationCoordinator
    @Binding var selectedTab: AppTab

    @State private var authAction: ProtectedAction?
    @State private var active: ActiveRequest?
    @State private var heldRequest: ActionRequest?
    @State private var durationGrant: UnblockGrant?

    private struct ActiveRequest {
        let token: UUID
        let target: UnblockTarget
        let keyType: KeyType?
    }

    private var unblockDurations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    func body(content: Content) -> some View {
        content
            .protectedAction(
                $authAction,
                requestedKeyType: active?.keyType,
                keyGroupID: active?.target.groupID,
                requestID: active?.token
            )
            .sheet(item: $durationGrant, onDismiss: durationSheetDismissed) { grant in
                UnblockDurationSheet(grant: grant)
            }
            .onOpenURL { coordinator.handle(url: $0) }
            .onChange(of: coordinator.pendingAction) { _, request in resolve(request) }
            .onChange(of: unlockInbox.pending, initial: true) { _, _ in takeInboxRequest() }
            .onChange(of: scenePhase) { _, _ in takeInboxRequest() }
            .onChange(of: screenTimeService.authorizationState) { _, _ in takeInboxRequest() }
            .onChange(of: groups) { _, _ in syncGroups() }
            .onChange(of: keys) { _, _ in syncWidget() }
            .onChange(of: screenTimeService.lastUpdate) { _, _ in syncWidget() }
            .onChange(of: unblockDurations) { _, _ in syncWidget() }
            .onAppear { syncGroups() }
    }

    private func syncWidget() {
        WidgetSync.sync(
            groups: groups,
            keys: keys,
            settings: allSettings.first,
            screenTimeService: screenTimeService
        )
    }

    private func syncGroups() {
        syncWidget()
        NormalShortcuts.updateAppShortcutParameters()
    }

    private func takeInboxRequest() {
        guard scenePhase == .active,
              screenTimeService.authorizationState == .authorized,
              durationGrant == nil,
              let request = unlockInbox.take(),
              let settings = allSettings.first,
              let target = target(for: request.groupID),
              target.canUnblock(
                  status: screenTimeService.blockStatus(of: target, settings: settings),
                  timedUnblockService: timedUnblockService
              )
        else { return }
        coordinator.requestUnblock(request)
    }

    private func durationSheetDismissed() {
        replayHeldRequest()
        takeInboxRequest()
    }

    private func resolve(_ request: ActionRequest?) {
        guard let request else { return }
        coordinator.clearPendingAction()
        guard durationGrant == nil else {
            heldRequest = request
            return
        }
        guard allSettings.first?.hasCompletedOnboarding == true else { return }

        switch request.action {
        case let .unblock(unblock):
            guard let target = target(for: unblock.groupID) else { return }
            present(ActiveRequest(token: request.token, target: target, keyType: unblock.keyType))
            authAction = .weaken { unlock(target, duration: unblock.duration, proof: $0) }
        case let .blockGroup(groupID):
            guard let group = groups.first(where: { $0.id == groupID }) else { return }
            present(ActiveRequest(token: request.token, target: .group(group), keyType: nil))
            authAction = .tighten { block(group) }
        }
    }

    private func replayHeldRequest() {
        guard let held = heldRequest else { return }
        heldRequest = nil
        resolve(held)
    }

    private func target(for groupID: UUID?) -> UnblockTarget? {
        if let groupID {
            return groups.first { $0.id == groupID }.map(UnblockTarget.group)
        }
        return selectedApps.first.map(UnblockTarget.all)
    }

    private func present(_ request: ActiveRequest) {
        selectedTab = request.target.groupID == nil ? .home : .groups
        active = request
    }

    private func unlock(_ target: UnblockTarget, duration request: UnlockDurationRequest, proof: KeyProof) {
        guard let grant = UnblockGrant(target, proof: proof) else { return }
        guard let settings = allSettings.first, let length = settings.unblockLength(for: request) else {
            durationGrant = grant
            return
        }
        try? BlockActions.unblock(
            grant,
            for: length,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
    }

    private func block(_ group: AppGroup) {
        BlockActions.blockGroup(
            group,
            settings: allSettings.unwrapped,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
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
