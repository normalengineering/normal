import FamilyControls
import Foundation
import SwiftData
import Testing

@testable import Normal

@MainActor
struct EditWhileBlockedEdgeCaseTests {
    @Test func removingBlockedAppsFromMainSelectionUnblocksThemImmediately() {
        let h = BlockingHarness(mainApps: [1, 2, 3], customDomains: ["a.com", "b.com"])
        h.blockAll()
        #expect(h.blocked == h.apps(1, 2, 3))
        #expect(h.blockedDomains == ["a.com", "b.com"])

        let updatedSelection = TokenFixtures.selection(apps: [1, 2])
        let updatedDomains = ["a.com"]
        h.main.selection = updatedSelection
        h.main.customDomains = updatedDomains

        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2, 3]),
            oldCustomDomains: ["a.com", "b.com"],
            to: updatedSelection,
            newCustomDomains: updatedDomains,
            schedules: h.schedules,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(h.blocked == h.apps(1, 2))
        #expect(h.blockedDomains == ["a.com"])
        #expect(!h.screenTime.isCustomDomainShielded("b.com"))
        #expect(h.screenTime.isCustomDomainShielded("a.com"))
    }

    @Test func removingAppFromMainSelectionStopsActiveScheduleFromOrphaningIt() throws {
        let h = BlockingHarness(mainApps: [1, 2], startingAt: 9)
        let schedule = try h.addSchedule([1, 2], from: (9, 0), minutes: 120, block: true)
        h.wake(at: h.at(9, 30))
        #expect(h.blocked == h.apps(1, 2))

        let narrowed = TokenFixtures.selection(apps: [1])
        h.main.selection = narrowed

        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2]),
            oldCustomDomains: [],
            to: narrowed,
            newCustomDomains: [],
            schedules: h.schedules,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(h.blocked == h.apps(1))
        #expect(!schedule.selection.isSubset(of: narrowed))
    }

    @Test func emptyingMainSelectionDuringTimedUnblockCancelsTimerAndLiftsAppDeletion() throws {
        let h = BlockingHarness(mainApps: [1, 2])
        h.settings.blockAllPreventsAppDelete = true
        h.blockAll()
        #expect(h.appDeletionBlocked)

        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)
        #expect(h.timedUnblock.isMainUnblockActive)
        #expect(!h.appDeletionBlocked)

        h.passTime(to: h.at(10, 5))
        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2]),
            oldCustomDomains: [],
            to: FamilyActivitySelection(),
            newCustomDomains: [],
            schedules: h.schedules,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(!h.timedUnblock.isMainUnblockActive)
        h.wake(at: h.at(10, 35))
        #expect(h.blocked.isEmpty)
        #expect(!h.appDeletionBlocked)
    }

    @Test func editingGroupDuringTimedUnblockNeverExpandsUnblockToAddedBlockedApps() throws {
        let h = BlockingHarness(mainApps: [1, 2, 3])
        let group = h.group([1, 2])
        h.blockAll()

        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .thirtyMinutes)
        #expect(h.blocked == h.apps(3))

        h.passTime(to: h.at(10, 5))
        h.timedUnblock.updateGroupSelection(
            groupId: group.id,
            selection: TokenFixtures.selection(apps: [1, 3]),
            screenTimeService: h.screenTime
        )

        #expect(h.blocked == h.apps(2, 3))
    }

    @Test func deletingGroupDuringTimedUnblockCancelsItsTimerAndReconciles() throws {
        let container = try InMemoryModelContainer.make()
        let context = container.mainContext
        let h = BlockingHarness(mainApps: [1, 2])
        let group = h.group([1])
        let groupKey = Key(name: "Social", type: .qr, rawValue: "G", groupID: group.id)
        context.insert(group)
        context.insert(groupKey)
        try context.save()

        h.blockAll()
        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .thirtyMinutes)
        #expect(h.blocked == h.apps(2))

        BlockActions.deleteGroup(
            group,
            keys: [groupKey],
            from: context,
            timedUnblockService: h.timedUnblock,
            screenTimeService: h.screenTime
        )
        try context.save()

        #expect(!h.timedUnblock.isGroupUnblockActive(groupId: group.id))
        #expect(h.blocked == h.apps(1, 2))
        #expect(try context.fetch(FetchDescriptor<Key>()).isEmpty)
    }

    @Test func permanentUnblockAllCancelsActiveGroupTimedUnblocksSoLaterSchedulesRun() throws {
        let h = BlockingHarness(mainApps: [1, 2])
        let group = h.group([1])
        h.blockAll()

        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .oneHour)
        #expect(h.timedUnblock.isGroupUnblockActive(groupId: group.id))

        h.passTime(to: h.at(10, 5))
        let grant = try #require(UnblockGrant(.all(h.main), proof: KeyProof(keyGroupID: nil)))
        try BlockActions.unblock(
            grant,
            for: .permanent,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock
        )

        #expect(h.timedUnblock.activeUnblocks.isEmpty)
        try h.addSchedule([1], from: (10, 30), minutes: 60, block: true)
        h.wake(at: h.at(10, 35))
        #expect(h.blocked == h.apps(1))
    }

    @Test func editingPermanentScheduleRulesPreservesAppliedStateWithoutRetroactiveFiring() throws {
        let h = BlockingHarness(mainApps: [1, 2], startingAt: 8)
        let permanent = try h.addSchedule([1], from: (9, 0), minutes: 15, block: true, timed: false)
        h.wake(at: h.at(9, 5))
        #expect(h.blocked == h.apps(1))

        h.passTime(to: h.at(11))
        permanent.selection = TokenFixtures.selection(apps: [1, 2])
        try h.scheduleService.syncAndPersist(permanent, allSchedules: h.schedules, screenTimeService: h.screenTime)

        #expect(h.blocked == h.apps(1))

        let permanent2 = try h.addSchedule([2], from: (11, 30), minutes: 15, block: true, timed: false)
        h.wake(at: h.at(11, 35))
        #expect(h.blocked == h.apps(1, 2))

        h.passTime(to: h.at(12))
        h.screenTime.unblock(selection: TokenFixtures.selection(apps: [2]))
        #expect(h.blocked == h.apps(1))

        h.passTime(to: h.at(12, 30))
        permanent2.startMinute = 45
        try h.scheduleService.syncAndPersist(permanent2, allSchedules: h.schedules, screenTimeService: h.screenTime)

        #expect(h.blocked == h.apps(1))
    }

    @Test func togglingAndDeletingOtherScheduleKeepsNeedsSyncScheduleConstrained() throws {
        let h = BlockingHarness(mainApps: [1, 2], startingAt: 9)
        let scheduleA = try h.addSchedule([1, 2], from: (10, 0), minutes: 120, block: true)
        let scheduleB = try h.addSchedule([1], from: (13, 0), minutes: 60, block: true)

        h.passTime(to: h.at(9, 30))
        let narrowed = TokenFixtures.selection(apps: [1])
        h.main.selection = narrowed
        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2]),
            oldCustomDomains: [],
            to: narrowed,
            newCustomDomains: [],
            schedules: h.schedules,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        let constraint = SelectionConstraint(selection: narrowed, customDomains: [])
        try h.scheduleService.toggleEnabled(
            scheduleB,
            allSchedules: h.schedules,
            screenTimeService: h.screenTime,
            constrainedTo: constraint
        )
        h.scheduleService.remove(
            scheduleB,
            remaining: [scheduleA],
            screenTimeService: h.screenTime,
            constrainedTo: constraint
        )

        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1))
    }

    @Test func editingGroupToDisjointAppsCancelsItsTimedUnblock() throws {
        let h = BlockingHarness(mainApps: [1, 2, 3])
        let group = h.group([1, 2])
        h.blockAll()

        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .thirtyMinutes)
        #expect(h.timedUnblock.isGroupUnblockActive(groupId: group.id))

        h.passTime(to: h.at(10, 5))
        h.timedUnblock.updateGroupSelection(
            groupId: group.id,
            selection: TokenFixtures.selection(apps: [3]),
            screenTimeService: h.screenTime
        )

        #expect(!h.timedUnblock.isGroupUnblockActive(groupId: group.id))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func removingGroupAppsFromMainSelectionCancelsGroupTimedUnblock() throws {
        let h = BlockingHarness(mainApps: [1, 2, 3])
        let group = h.group([1, 2])
        h.blockAll()

        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .thirtyMinutes)
        #expect(h.timedUnblock.isGroupUnblockActive(groupId: group.id))

        h.passTime(to: h.at(10, 5))
        let remaining = TokenFixtures.selection(apps: [3])
        h.main.selection = remaining
        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2, 3]),
            oldCustomDomains: [],
            to: remaining,
            newCustomDomains: [],
            schedules: h.schedules,
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(!h.timedUnblock.isGroupUnblockActive(groupId: group.id))
        #expect(h.blocked == h.apps(3))
    }

    @Test func disablingCustomDomainsCancelsWebsiteOnlyTimedUnblockAndClearsAppDeletion() throws {
        let h = BlockingHarness(mainApps: [], customDomains: ["reddit.com"])
        h.settings.blockAllPreventsAppDelete = true
        h.blockAll()
        #expect(h.blockedDomains == ["reddit.com"])
        #expect(h.appDeletionBlocked)

        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)
        #expect(h.timedUnblock.isMainUnblockActive)
        #expect(!h.appDeletionBlocked)

        h.passTime(to: h.at(10, 5))
        BlockActions.setCustomDomainsEnabled(
            false,
            settings: h.settings,
            schedules: h.schedules,
            mainSelection: h.main,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(!h.settings.enableCustomDomains)
        #expect(!h.timedUnblock.isMainUnblockActive)
        h.wake(at: h.at(10, 35))
        #expect(h.blockedDomains.isEmpty)
        #expect(!h.appDeletionBlocked)
    }

    @Test func renamingScheduleWithHiddenCustomDomainsDoesNotResetActivation() throws {
        let h = BlockingHarness(mainApps: [1], customDomains: ["reddit.com"], startingAt: 9)
        h.scheduleService.mirrorCustomDomainsEnabled(false)
        let weekday = Calendar.current.component(.weekday, from: h.day)
        let schedule = BlockSchedule(
            name: "Focus",
            selection: TokenFixtures.selection(apps: [1]),
            startHour: 9,
            startMinute: 0,
            durationMinutes: 120,
            weekdays: [weekday],
            shouldBlock: true,
            isTimed: true,
            isEnabled: true,
            customDomains: ["reddit.com"]
        )
        let constraint = SelectionConstraint(
            selection: h.main.selection,
            customDomains: h.main.customDomains,
            customDomainsEnabled: false
        )
        try h.scheduleService.syncAndPersist(
            schedule,
            allSchedules: [schedule],
            screenTimeService: h.screenTime,
            constrainedTo: constraint
        )

        h.passTime(to: h.at(9, 30))
        h.screenTime.unblock(selection: TokenFixtures.selection(apps: [1]))
        #expect(h.blocked.isEmpty)

        h.passTime(to: h.at(9, 45))
        schedule.name = "Deep Focus"
        try h.scheduleService.syncAndPersist(
            schedule,
            allSchedules: [schedule],
            screenTimeService: h.screenTime,
            constrainedTo: constraint
        )

        #expect(h.blocked.isEmpty)
    }

    @Test func disablingCustomDomainsClearsManualDomainStateAgainstResurrection() {
        let h = BlockingHarness(mainApps: [1], customDomains: ["reddit.com"])
        h.blockAll()
        #expect(h.blockedDomains == ["reddit.com"])

        BlockActions.setCustomDomainsEnabled(
            false,
            settings: h.settings,
            schedules: h.schedules,
            mainSelection: h.main,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )
        #expect(h.blockedDomains.isEmpty)

        BlockActions.setCustomDomainsEnabled(
            true,
            settings: h.settings,
            schedules: h.schedules,
            mainSelection: h.main,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )
        #expect(h.blockedDomains.isEmpty)
    }

    @Test func reEnablingCustomDomainsReSyncsScheduleDomainsToSharedStore() throws {
        let h = BlockingHarness(mainApps: [1, 2], customDomains: ["reddit.com"], startingAt: 9)
        let weekday = Calendar.current.component(.weekday, from: h.day)
        let schedule = BlockSchedule(
            name: "Focus",
            selection: TokenFixtures.selection(apps: [1]),
            startHour: 10,
            startMinute: 0,
            durationMinutes: 120,
            weekdays: [weekday],
            shouldBlock: true,
            isTimed: true,
            isEnabled: true,
            customDomains: ["reddit.com"]
        )
        try h.scheduleService.syncAndPersist(
            schedule,
            allSchedules: [schedule],
            screenTimeService: h.screenTime,
            constrainedTo: h.main.effectiveConstraint(customDomainsEnabled: true)
        )
        #expect(h.store.schedules.first?.customDomains == ["reddit.com"])

        h.passTime(to: h.at(9, 15))
        BlockActions.setCustomDomainsEnabled(
            false,
            settings: h.settings,
            schedules: [schedule],
            mainSelection: h.main,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        let narrowed = TokenFixtures.selection(apps: [1])
        h.main.selection = narrowed
        BlockActions.updateMainSelection(
            from: TokenFixtures.selection(apps: [1, 2]),
            oldCustomDomains: h.main.customDomains,
            to: narrowed,
            newCustomDomains: h.main.customDomains,
            schedules: [schedule],
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )
        #expect(h.store.schedules.first?.customDomains == [])

        h.passTime(to: h.at(9, 30))
        BlockActions.setCustomDomainsEnabled(
            true,
            settings: h.settings,
            schedules: [schedule],
            mainSelection: h.main,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock,
            scheduleService: h.scheduleService
        )

        #expect(h.store.schedules.first?.customDomains == ["reddit.com"])
        h.wake(at: h.at(10, 15))
        #expect(h.blockedDomains == ["reddit.com"])
    }

    @Test func unblockingOrphanedShieldsRequiresGlobalProofAndClearsAllState() throws {
        let h = BlockingHarness(mainApps: [1, 2])
        let group = h.group([1])
        h.settings.blockAllPreventsAppDelete = true
        h.blockAll()
        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(group, .thirtyMinutes)

        BlockActions.unblockOrphanedShields(
            proof: KeyProof(keyGroupID: group.id),
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock
        )
        #expect(h.blocked == h.apps(2))
        #expect(h.timedUnblock.isGroupUnblockActive(groupId: group.id))

        BlockActions.unblockOrphanedShields(
            proof: KeyProof(keyGroupID: nil),
            settings: h.settings,
            screenTimeService: h.screenTime,
            timedUnblockService: h.timedUnblock
        )
        #expect(h.blocked.isEmpty)
        #expect(!h.appDeletionBlocked)
        #expect(h.timedUnblock.activeUnblocks.isEmpty)
    }
}
