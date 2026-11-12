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

    @State private var authAction: (@MainActor () -> Void)?
    @State private var actionGroup: AppGroup?
    @State private var keyType: KeyType?
    @State private var allowBypass = false
    @State private var requestID: UUID?
    @State private var durationTarget: DurationTarget?

    private enum DurationTarget: Identifiable {
        case all(SelectedApps)
        case group(AppGroup)

        var id: String {
            switch self {
            case .all: "all"
            case let .group(group): group.id.uuidString
            }
        }
    }

    private var unblockDurations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    func body(content: Content) -> some View {
        content
            .protectedAction(
                $authAction,
                allowBypass: allowBypass,
                requestedKeyType: keyType,
                keyGroupID: actionGroup?.id,
                requestID: requestID
            )
            .sheet(item: $durationTarget, onDismiss: takeInboxRequest) { target in
                switch target {
                case let .all(mainSelection):
                    MainTimedUnblockSheet(mainSelection: mainSelection)
                case let .group(group):
                    GroupTimedUnblockSheet(group: group)
                }
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
              durationTarget == nil,
              let request = unlockInbox.take()
        else { return }
        coordinator.requestUnlock(groupID: request.groupID, duration: request.duration, keyType: request.keyType)
    }

    private func resolve(_ request: ActionRequest?) {
        defer { coordinator.clearPendingAction() }
        guard let request,
              durationTarget == nil,
              allSettings.first?.hasCompletedOnboarding == true
        else { return }
        let group = groups.first { $0.id == request.groupID }
        guard group != nil || (request.groupID == nil && !selectedApps.isEmpty) else { return }

        switch request.action {
        case let .unlock(duration, requestedKeyType):
            target(group, requestID: request.token)
            keyType = requestedKeyType
            allowBypass = false
            authAction = { unlock(group, duration: duration) }
        case .block:
            guard let group else { return }
            target(group, requestID: request.token)
            keyType = nil
            allowBypass = true
            authAction = { block(group) }
        }
    }

    private func target(_ group: AppGroup?, requestID: UUID) {
        selectedTab = group == nil ? .home : .groups
        actionGroup = group
        self.requestID = requestID
    }

    private func unlock(_ group: AppGroup?, duration request: UnlockDurationRequest) {
        guard let settings = allSettings.first, let duration = settings.duration(for: request) else {
            durationTarget = group.map(DurationTarget.group) ?? selectedApps.first.map(DurationTarget.all)
            return
        }
        if let group {
            try? timedUnblockService.startGroup(
                duration: duration,
                group: group,
                settings: settings,
                screenTimeService: screenTimeService
            )
        } else if let mainSelection = selectedApps.first {
            try? timedUnblockService.startMain(
                duration: duration,
                mainSelection: mainSelection,
                settings: settings,
                screenTimeService: screenTimeService
            )
        }
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
