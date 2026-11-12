import AppIntents
import SwiftData
import SwiftUI

private struct WidgetActionResponder: ViewModifier {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)]) private var groups: [AppGroup]
    @Query private var keys: [Key]
    @Query private var selectedApps: [SelectedApps]

    let coordinator: NavigationCoordinator
    @Binding var selectedTab: AppTab

    @State private var authAction: (@MainActor () -> Void)?
    @State private var active: ActiveRequest?
    @State private var heldRequest: ActionRequest?
    @State private var durationTarget: UnblockTarget?

    private struct ActiveRequest {
        let token: UUID
        let target: UnblockTarget
        let keyType: KeyType?
        let allowBypass: Bool
    }

    private var unblockDurations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    func body(content: Content) -> some View {
        content
            .protectedAction(
                $authAction,
                allowBypass: active?.allowBypass ?? false,
                requestedKeyType: active?.keyType,
                keyGroupID: active?.target.groupID,
                requestID: active?.token
            )
            .sheet(item: $durationTarget, onDismiss: replayHeldRequest) { target in
                UnblockDurationSheet(target: target)
            }
            .onOpenURL { coordinator.handle(url: $0) }
            .onChange(of: coordinator.pendingAction) { _, request in resolve(request) }
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

    private func resolve(_ request: ActionRequest?) {
        guard let request else { return }
        coordinator.clearPendingAction()
        guard durationTarget == nil else {
            heldRequest = request
            return
        }
        guard allSettings.first?.hasCompletedOnboarding == true else { return }

        switch request.action {
        case let .unblock(unblock):
            guard let target = target(for: unblock.groupID) else { return }
            present(ActiveRequest(token: request.token, target: target, keyType: unblock.keyType, allowBypass: false))
            authAction = { unlock(target, duration: unblock.duration) }
        case let .blockGroup(groupID):
            guard let group = groups.first(where: { $0.id == groupID }) else { return }
            present(ActiveRequest(token: request.token, target: .group(group), keyType: nil, allowBypass: true))
            authAction = { block(group) }
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

    private func unlock(_ target: UnblockTarget, duration request: UnlockDurationRequest) {
        guard let settings = allSettings.first, let duration = settings.duration(for: request) else {
            durationTarget = target
            return
        }
        try? timedUnblockService.start(
            target,
            duration: duration,
            settings: settings,
            screenTimeService: screenTimeService
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
