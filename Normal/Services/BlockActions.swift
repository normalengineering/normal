import FamilyControls
import Foundation
import SwiftData
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
        case .timed(let duration):
            timing = try timedUnblockService.start(
                grant,
                duration: duration,
                settings: settings,
                screenTimeService: screenTimeService
            )
        case .permanent:
            if grant.target.group == nil {
                timedUnblockService.clearAll()
            } else if let group = grant.target.group, timedUnblockService.isGroupUnblockActive(groupId: group.id) {
                timedUnblockService.cancelGroup(groupId: group.id)
            }
            screenTimeService.unblockPermanently(grant, settings: settings)
            timing = .exact
        }
        playHaptic()
        return timing
    }

    static func updateMainSelection(
        from oldSelection: FamilyActivitySelection,
        oldCustomDomains: [String],
        to newSelection: FamilyActivitySelection,
        newCustomDomains: [String],
        schedules: [BlockSchedule],
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService
    ) {
        let effectiveNewDomains = settings.enableCustomDomains ? newCustomDomains : []
        let effectiveOldDomains = settings.enableCustomDomains ? oldCustomDomains : []
        if !schedules.isEmpty {
            scheduleService.syncAllToSharedStore(
                schedules,
                constrainedTo: (selection: newSelection, customDomains: effectiveNewDomains)
            )
        }
        if timedUnblockService.isMainUnblockActive {
            timedUnblockService.updateMainSelection(
                newSelection,
                customDomains: effectiveNewDomains,
                screenTimeService: screenTimeService
            )
        } else {
            let becameEmpty = newSelection.isEmpty && effectiveNewDomains.isEmpty
            if becameEmpty {
                timedUnblockService.clearAll()
            } else {
                timedUnblockService.pruneGroupUnblocks(
                    to: newSelection,
                    customDomains: effectiveNewDomains,
                    screenTimeService: screenTimeService
                )
            }
            screenTimeService.unblockRemovedFromMain(
                from: oldSelection,
                customDomains: effectiveOldDomains,
                to: newSelection,
                customDomains: effectiveNewDomains,
                clearAppDeletion: becameEmpty && settings.blockAllPreventsAppDelete
            )
        }
    }

    static func deleteGroup(
        _ group: AppGroup,
        keys: [Key],
        from context: ModelContext,
        timedUnblockService: TimedUnblockService,
        screenTimeService: any ScreenTimeProviding
    ) {
        let hadTimedUnblock = timedUnblockService.isGroupUnblockActive(groupId: group.id)
        if hadTimedUnblock {
            timedUnblockService.cancelGroup(groupId: group.id)
        }
        group.deleteCascading(keys: keys, from: context)
        if hadTimedUnblock {
            screenTimeService.reconcile()
        }
    }

    static func emergencyUnblock(
        schedules: [BlockSchedule],
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService,
        usageLimitService: UsageLimitService,
        editSessionService: EditSessionService? = nil
    ) {
        timedUnblockService.discardAll()
        scheduleService.disableAll(schedules, screenTimeService: screenTimeService)
        usageLimitService.overrideToday()
        screenTimeService.removeAllRestrictions()
        editSessionService?.grantEmergencyAccess()
        playHaptic()
    }

    private static func playHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func validate(isAuthorized: Bool, hasCompletedOnboarding: Bool, keys: [Key], groupID: UUID? = nil) throws {
        try validateSetup(isAuthorized: isAuthorized, hasCompletedOnboarding: hasCompletedOnboarding)
        guard !Key.scoped(keys, toGroup: groupID).isEmpty else { throw BlockIntentError.noGlobalKey }
    }

    static func validateSetup(isAuthorized: Bool, hasCompletedOnboarding: Bool) throws {
        guard hasCompletedOnboarding else { throw BlockIntentError.setupIncomplete }
        guard isAuthorized else { throw BlockIntentError.screenTimeNotAuthorized }
    }
}
