import Foundation
import UIKit

enum BlockActions {
    static func blockAll(
        mainSelection: SelectedApps,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) {
        timedUnblockService.clearAll()
        screenTimeService.blockAll(
            selection: mainSelection.selection,
            customDomains: settings.enableCustomDomains ? mainSelection.customDomains : [],
            blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
        )
        playHaptic()
    }

    static func blockGroup(
        _ group: AppGroup,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) {
        let customDomains = settings.enableCustomDomains ? group.customDomains : []
        if timedUnblockService.isGroupUnblockActive(groupId: group.id) {
            timedUnblockService.cancelGroup(groupId: group.id)
        }
        screenTimeService.block(selection: group.selection, customDomains: customDomains)
        playHaptic()
    }

    @discardableResult
    static func unblock(
        _ grant: UnblockGrant,
        for length: UnblockLength,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) throws -> UnblockTiming {
        let timing: UnblockTiming
        switch length {
        case let .timed(duration):
            timing = try timedUnblockService.start(
                grant,
                duration: duration,
                settings: settings,
                screenTimeService: screenTimeService
            )
        case .permanent:
            screenTimeService.unblockPermanently(grant, settings: settings)
            timing = .exact
        }
        playHaptic()
        return timing
    }

    static func emergencyUnblock(
        schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService,
        usageLimitService: UsageLimitService
    ) {
        timedUnblockService.discardAll()
        scheduleService.disableAll(schedules, screenTimeService: screenTimeService)
        usageLimitService.overrideToday()
        screenTimeService.removeAllRestrictions()
        playHaptic()
    }

    private static func playHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func validate(isAuthorized: Bool, hasCompletedOnboarding: Bool, keys: [Key]) throws {
        try validateSetup(isAuthorized: isAuthorized, hasCompletedOnboarding: hasCompletedOnboarding)
        guard Key.hasGlobalKey(in: keys) else { throw BlockIntentError.noGlobalKey }
    }

    static func validateSetup(isAuthorized: Bool, hasCompletedOnboarding: Bool) throws {
        guard hasCompletedOnboarding else { throw BlockIntentError.setupIncomplete }
        guard isAuthorized else { throw BlockIntentError.screenTimeNotAuthorized }
    }
}
