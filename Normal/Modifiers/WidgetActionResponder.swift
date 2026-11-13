import AppIntents
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
    @State private var active: ActiveRequest?
    @State private var heldRequest: GroupActionRequest?
    @State private var durationTarget: UnblockTarget?

    private struct ActiveRequest {
        let token: UUID
        let group: AppGroup
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
                defaultKeyType: active?.keyType,
                keyGroupID: active?.group.id,
                requestID: active?.token
            )
            .sheet(item: $durationTarget, onDismiss: replayHeldRequest) { target in
                UnblockDurationSheet(target: target)
            }
            .onOpenURL { coordinator.handle(url: $0) }
            .onChange(of: coordinator.pendingGroupAction) { _, request in resolve(request) }
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

    private func resolve(_ request: GroupActionRequest?) {
        guard let request else { return }
        coordinator.clearPendingGroupAction()
        guard durationTarget == nil else {
            heldRequest = request
            return
        }
        guard allSettings.first?.hasCompletedOnboarding == true,
              let group = groups.first(where: { $0.id == request.groupID })
        else { return }
        selectedTab = .groups

        switch request.action {
        case let .unlock(duration, keyType):
            active = ActiveRequest(token: request.token, group: group, keyType: keyType, allowBypass: false)
            authAction = { unlock(group, duration: duration) }
        case .block:
            active = ActiveRequest(token: request.token, group: group, keyType: nil, allowBypass: true)
            authAction = { block(group) }
        }
    }

    private func replayHeldRequest() {
        guard let held = heldRequest else { return }
        heldRequest = nil
        resolve(held)
    }

    private func unlock(_ group: AppGroup, duration request: UnlockDurationRequest) {
        guard let settings = allSettings.first, let duration = settings.duration(for: request) else {
            durationTarget = .group(group)
            return
        }
        try? timedUnblockService.start(
            .group(group),
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
