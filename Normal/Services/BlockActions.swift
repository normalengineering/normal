import Foundation

enum BlockActions {
    static func blockAll(
        mainSelection: SelectedApps,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService
    ) {
        screenTimeService.applyShieldOnAll(
            selection: mainSelection.selection,
            customDomains: settings.enableCustomDomains ? mainSelection.customDomains : [],
            blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
        )
        timedUnblockService.clearAll()
        scheduleService.setScheduleOverride(false)
    }

    static func blockGroup(
        _ group: AppGroup,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) {
        let customDomains = settings.enableCustomDomains ? group.customDomains : []
        if timedUnblockService.isGroupUnblockActive(groupId: group.id) {
            timedUnblockService.cancelGroup(
                groupId: group.id,
                selection: group.selection,
                customDomains: customDomains,
                screenTimeService: screenTimeService
            )
        } else {
            screenTimeService.addToShields(selection: group.selection, customDomains: customDomains)
        }
    }

    static func validate(isAuthorized: Bool, hasCompletedOnboarding: Bool, keys: [Key]) throws {
        guard hasCompletedOnboarding else { throw BlockIntentError.setupIncomplete }
        guard isAuthorized else { throw BlockIntentError.screenTimeNotAuthorized }
        guard Key.hasGlobalKey(in: keys) else { throw BlockIntentError.noGlobalKey }
    }
}
