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

    static func unblockOrphanedShields(
        proof: KeyProof,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) {
        guard proof.coversAllApps else { return }
        timedUnblockService.clearAll()
        screenTimeService.unblockAll(blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete)
        playHaptic()
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
        let constraint = SelectionConstraint(
            selection: newSelection,
            customDomains: newCustomDomains,
            customDomainsEnabled: settings.enableCustomDomains
        )
        let effectiveNewDomains = constraint.effectiveCustomDomains
        let effectiveOldDomains = settings.enableCustomDomains ? oldCustomDomains : []
        if !schedules.isEmpty {
            scheduleService.syncAllToSharedStore(schedules, constrainedTo: constraint)
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

    static func setCustomDomainsEnabled(
        _ enabled: Bool,
        settings: Settings,
        schedules: [BlockSchedule],
        mainSelection: SelectedApps?,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService
    ) {
        settings.enableCustomDomains = enabled
        scheduleService.mirrorCustomDomainsEnabled(enabled)
        if enabled {
            if !schedules.isEmpty {
                scheduleService.syncAllToSharedStore(
                    schedules,
                    constrainedTo: mainSelection?.effectiveConstraint(customDomainsEnabled: true)
                )
            }
            screenTimeService.reconcile()
        } else {
            timedUnblockService.handleCustomDomainsDisabled(screenTimeService: screenTimeService)
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

    static func validate(isAuthorized: Bool, hasCompletedOnboarding: Bool, keys: [Key], groupID: UUID? = nil) throws {
        try validateSetup(isAuthorized: isAuthorized, hasCompletedOnboarding: hasCompletedOnboarding)
        guard !Key.scoped(keys, toGroup: groupID).isEmpty else { throw BlockIntentError.noGlobalKey }
    }

    static func validateSetup(isAuthorized: Bool, hasCompletedOnboarding: Bool) throws {
        guard hasCompletedOnboarding else { throw BlockIntentError.setupIncomplete }
        guard isAuthorized else { throw BlockIntentError.screenTimeNotAuthorized }
    }
}
