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
    @State private var actionGroup: AppGroup?
    @State private var keyType: KeyType?
    @State private var allowBypass = false
    @State private var requestID: UUID?
    @State private var durationTarget: UnblockTarget?

    private var unblockDurations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    func body(content: Content) -> some View {
        content
            .protectedAction(
                $authAction,
                allowBypass: allowBypass,
                defaultKeyType: keyType,
                keyGroupID: actionGroup?.id,
                requestID: requestID
            )
            .sheet(item: $durationTarget) { target in
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
        guard let request,
              durationTarget == nil,
              allSettings.first?.hasCompletedOnboarding == true,
              let group = groups.first(where: { $0.id == request.groupID })
        else {
            coordinator.clearPendingGroupAction()
            return
        }
        selectedTab = .groups
        actionGroup = group
        requestID = request.token

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
