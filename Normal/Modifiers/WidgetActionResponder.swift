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
    @State private var actionGroup: AppGroup?
    @State private var keyType: KeyType?
    @State private var allowBypass = false
    @State private var showDurationSheet = false
    @State private var showMainDurationSheet = false

    private var unblockDurations: [TimedUnblockDuration] {
        allSettings.first?.unblockDurations ?? TimedUnblockDuration.presets
    }

    private var customDomainsEnabled: Bool {
        allSettings.first?.enableCustomDomains ?? false
    }

    private func customDomains(for group: AppGroup) -> [String] {
        customDomainsEnabled ? group.customDomains : []
    }

    func body(content: Content) -> some View {
        content
            .protectedAction(
                $authAction,
                allowBypass: allowBypass,
                defaultKeyType: allSettings.first?.defaultKeyType,
                requestedKeyType: keyType,
                keyGroupID: actionGroup?.id
            )
            .sheet(isPresented: $showDurationSheet) {
                if let actionGroup {
                    GroupTimedUnblockSheet(group: actionGroup)
                }
            }
            .sheet(isPresented: $showMainDurationSheet) {
                if let mainSelection = selectedApps.first {
                    MainTimedUnblockSheet(mainSelection: mainSelection)
                }
            }
            .onOpenURL { coordinator.handle(url: $0) }
            .onChange(of: coordinator.pendingGroupAction, initial: true) { _, request in resolve(request) }
            .onChange(of: coordinator.pendingMainUnlock, initial: true) { _, request in resolveMain(request) }
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

    private func resolveMain(_ request: MainUnlockRequest?) {
        guard let request,
              allSettings.first?.hasCompletedOnboarding == true,
              let mainSelection = selectedApps.first
        else {
            coordinator.clearPendingMainUnlock()
            return
        }
        selectedTab = .home
        actionGroup = nil
        keyType = request.keyType
        allowBypass = false
        authAction = { unlockMain(mainSelection, duration: request.duration) }

        coordinator.clearPendingMainUnlock()
    }

    private func unlockMain(_ mainSelection: SelectedApps, duration request: UnlockDurationRequest) {
        guard let settings = allSettings.first else { return }
        if let duration = settings.duration(for: request) {
            try? timedUnblockService.startMain(
                duration: duration,
                mainSelection: mainSelection,
                settings: settings,
                screenTimeService: screenTimeService
            )
        } else {
            showMainDurationSheet = true
        }
    }

    private func unlock(_ group: AppGroup, duration request: UnlockDurationRequest) {
        if let duration = allSettings.first?.duration(for: request) {
            try? timedUnblockService.startGroup(
                duration: duration,
                groupId: group.id,
                selection: group.selection,
                customDomains: customDomains(for: group),
                screenTimeService: screenTimeService
            )
        } else {
            showDurationSheet = true
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
