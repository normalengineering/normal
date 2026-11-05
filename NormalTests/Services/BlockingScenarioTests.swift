import FamilyControls
import Foundation
import ManagedSettings
@testable import Normal
import Testing

@MainActor
struct BlockingScenarioTests {
    @Test func blockAllShieldsTheMainListAndUnblockAllLiftsIt() {
        let h = BlockingHarness()

        h.blockAll()
        #expect(h.blocked == h.apps(1, 2, 3))

        h.unblockAllPermanently()
        #expect(h.blocked.isEmpty)
    }

    @Test func groupsBlockAndUnblockOnlyTheirApps() {
        let h = BlockingHarness()
        let social = h.group([1, 2])

        h.blockGroup(social)
        #expect(h.blocked == h.apps(1, 2))

        h.blockAll()
        h.unblockGroupPermanently(h.group([2]))
        #expect(h.blocked == h.apps(1, 3))
    }

    @Test func manualStateSurvivesRepeatedWakeUps() {
        let h = BlockingHarness()
        h.blockAll()
        h.unblockGroupPermanently(h.group([3]))

        for hour in 9 ... 20 {
            h.wake(at: h.at(hour))
            #expect(h.blocked == h.apps(1, 2))
        }
    }

    @Test func unblockScheduleOpensDuringWindowAndReblocksAtEnd() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)

        h.wake(at: h.at(11, 59))
        #expect(h.blocked == h.apps(1, 2, 3))
        h.wake(at: h.at(12, 2))
        #expect(h.blocked == h.apps(2, 3))
        h.wake(at: h.at(15, 0))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func regressionTwoSchedulesEndingTogetherBothReblock() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        try h.addSchedule([2], from: (12, 0), minutes: 180, block: false)

        h.wake(at: h.at(12, 2))
        #expect(h.blocked == h.apps(3))

        h.wake(at: h.at(15, 0))
        h.wake(at: h.at(15, 0))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func regressionMissedEndIsRepairedByTheNextWakeUp() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        h.wake(at: h.at(12, 14))
        #expect(h.blocked == h.apps(2, 3))

        h.passTime(to: h.at(15, 0))
        #expect(h.blocked == h.apps(2, 3))

        h.openApp(at: h.at(17, 25))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func regressionMissedEndIsRepairedByAnUnrelatedCallback() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        try h.addSchedule([2], from: (12, 0), minutes: 180, block: false)
        h.wake(at: h.at(12, 14))

        h.passTime(to: h.at(15, 0))
        h.wake(at: h.at(15, 30))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func regressionOpeningTheAppMidWindowKeepsTheWindowState() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        let work = try h.addSchedule([2], from: (9, 0), minutes: 480, block: true)
        h.unblockGroupPermanently(h.group([2]))

        h.openApp(at: h.at(13))
        h.openApp(at: h.at(13, 1))
        #expect(h.blocked == h.apps(2, 3))
        #expect(h.activity.monitoredActivityNames.contains(SharedConstants.scheduleActivityName(for: work.id)))
    }

    @Test func openingTheAppMidWindowNoLongerRestartsSchedules() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        h.openApp(at: h.at(12, 30))
        h.activity.stopCalls.removeAll()
        h.activity.startCalls.removeAll()

        h.openApp(at: h.at(13))
        h.openApp(at: h.at(14))

        #expect(h.activity.stopCalls.isEmpty)
        #expect(h.activity.startCalls.isEmpty)
        #expect(h.blocked == h.apps(2, 3))
    }

    @Test func blockScheduleAddsAppsOnlyDuringItsWindow() throws {
        let h = BlockingHarness()
        try h.addSchedule([1], from: (9, 0), minutes: 60, block: true)

        h.wake(at: h.at(9, 30))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(10, 0))
        #expect(h.blocked.isEmpty)
    }

    @Test func overlappingWindowsLatestStartWins() throws {
        let h = BlockingHarness(startingAt: 4)
        try h.addSchedule([1], from: (5, 0), minutes: 60, block: true)
        try h.addSchedule([1], from: (5, 30), minutes: 60, block: false)

        h.wake(at: h.at(5, 15))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(5, 45))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(6, 15))
        #expect(h.blocked.isEmpty)
    }

    @Test func nestedUnblockWindowIsAnExceptionInsideABlockWindow() throws {
        let h = BlockingHarness()
        try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        try h.addSchedule([1], from: (12, 0), minutes: 60, block: false)

        h.wake(at: h.at(10))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(12, 30))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(13, 30))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(17, 30))
        #expect(h.blocked.isEmpty)
    }

    @Test func blockAllDuringAnUnblockWindowWinsUntilTheNextWindowStart() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        h.wake(at: h.at(12, 30))
        #expect(h.blocked == h.apps(2, 3))

        h.passTime(to: h.at(13))
        h.blockAll()
        #expect(h.blocked == h.apps(1, 2, 3))
        h.wake(at: h.at(15, 30))
        #expect(h.blocked == h.apps(1, 2, 3))
        h.wake(at: h.at(12, 30, dayOffset: 1))
        #expect(h.blocked == h.apps(2, 3))
    }

    @Test func permanentUnblockAllDuringABlockWindowHoldsUntilTheNextStart() throws {
        let h = BlockingHarness()
        try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        h.wake(at: h.at(9, 30))
        #expect(h.blocked == h.apps(1))

        h.passTime(to: h.at(10))
        h.unblockAllPermanently()
        h.wake(at: h.at(11))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(9, 30, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func creatingABlockScheduleMidWindowBlocksImmediately() throws {
        let h = BlockingHarness()
        h.passTime(to: h.at(10))
        h.unblockAllPermanently()

        h.passTime(to: h.at(13))
        try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        #expect(h.blocked == h.apps(1))
    }

    @Test func disablingAnUnblockScheduleMidWindowReblocks() throws {
        let h = BlockingHarness()
        h.blockAll()
        let lunch = try h.addSchedule([1], from: (12, 0), minutes: 60, block: false)
        h.wake(at: h.at(12, 15))
        #expect(h.blocked == h.apps(2, 3))

        try h.toggle(lunch)
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func deletingABlockScheduleMidWindowKeepsManualBlocks() throws {
        let h = BlockingHarness()
        h.blockGroup(h.group([1]))
        let work = try h.addSchedule([1, 4], from: (9, 0), minutes: 480, block: true)
        h.wake(at: h.at(10))
        #expect(h.blocked == h.apps(1, 4))

        h.delete(work)
        #expect(h.blocked == h.apps(1))
    }

    @Test func untimedScheduleHoldsUntilAManualAction() throws {
        let h = BlockingHarness()
        try h.addSchedule([1], from: (9, 0), minutes: 15, block: true, timed: false)
        #expect(h.blocked.isEmpty)

        h.wake(at: h.at(9, 1))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(20))
        #expect(h.blocked == h.apps(1))

        h.unblockGroupPermanently(h.group([1]))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(9, 1, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func editingAnUntimedScheduleAfterItFiredKeepsItsBlock() throws {
        let h = BlockingHarness()
        let permanent = try h.addSchedule([1], from: (9, 0), minutes: 15, block: true, timed: false)
        h.wake(at: h.at(9, 1))

        h.passTime(to: h.at(13))
        permanent.name = "Renamed"
        try h.scheduleService.syncAndPersist(permanent, allSchedules: h.schedules, screenTimeService: h.screenTime)
        #expect(h.blocked == h.apps(1))
    }

    @Test func weekdayFilterIsRespected() throws {
        let h = BlockingHarness()
        let weekday = Calendar.current.component(.weekday, from: h.day)
        let otherDays = Set(1 ... 7).subtracting([weekday])
        try h.addSchedule([1], from: (9, 0), minutes: 60, block: true, weekdays: otherDays)

        h.wake(at: h.at(9, 30))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(9, 30, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func timedUnblockAllExpiresBackToThePreviousState() throws {
        let h = BlockingHarness()
        h.blockAll()
        h.unblockGroupPermanently(h.group([3]))

        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)
        #expect(h.blocked.isEmpty)

        h.wake(at: h.at(10, 29))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2))
    }

    @Test func blockingAGroupDuringTimedUnblockAllAppliesNowAndAfter() throws {
        let h = BlockingHarness()
        h.blockAll()
        h.unblockGroupPermanently(h.group([3]))
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)

        h.passTime(to: h.at(10, 10))
        h.blockGroup(h.group([3]))
        #expect(h.blocked == h.apps(3))

        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func blockAllNowEndsTheTimedUnblockAndBlocksEverything() throws {
        let h = BlockingHarness()
        h.blockGroup(h.group([1]))
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)

        h.passTime(to: h.at(10, 5))
        h.blockAllNow()
        #expect(h.blocked == h.apps(1, 2, 3))
        #expect(h.store.timedUnblocks.isEmpty)
        h.wake(at: h.at(10, 45))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func timedUnblockAllSuppressesBlockWindowsUntilItExpires() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([4], from: (10, 20), minutes: 40, block: true)
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)

        h.wake(at: h.at(10, 25))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 3, 4))
    }

    @Test func groupTimedUnblockOpensTheGroupAndReblocksAtExpiry() throws {
        let h = BlockingHarness()
        h.blockAll()
        let social = h.group([1, 2])
        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(social, .fifteenMinutes)
        #expect(h.blocked == h.apps(3))

        h.wake(at: h.at(10, 15))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func blockingAGroupDuringItsTimedUnblockCancelsIt() throws {
        let h = BlockingHarness()
        h.blockAll()
        let social = h.group([1, 2])
        h.passTime(to: h.at(10))
        try h.unblockGroupTimed(social, .oneHour)

        h.passTime(to: h.at(10, 5))
        h.blockGroup(social)
        #expect(h.blocked == h.apps(1, 2, 3))
        #expect(!h.timedUnblock.isGroupUnblockActive(groupId: social.id))
    }

    @Test func groupTimedUnblockBeatsABlockWindow() throws {
        let h = BlockingHarness()
        let social = h.group([1])
        try h.addSchedule([1, 2], from: (10, 0), minutes: 60, block: true)
        h.passTime(to: h.at(10, 5))
        try h.unblockGroupTimed(social, .fifteenMinutes)
        #expect(h.blocked == h.apps(2))

        h.wake(at: h.at(10, 20))
        #expect(h.blocked == h.apps(1, 2))
    }

    @Test func emergencyUnblockClearsEverythingAndKeepsSchedulesOff() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([4], from: (9, 0), minutes: 60, block: true)
        h.passTime(to: h.at(8, 30))
        try h.unblockGroupTimed(h.group([1]), .oneHour)

        h.emergencyUnblock()
        #expect(h.blocked.isEmpty)
        #expect(h.schedules.allSatisfy { !$0.isEnabled })

        h.wake(at: h.at(9, 30))
        #expect(h.blocked.isEmpty)
    }

    @Test func preventAppDeleteFollowsBlockAllAndTimedUnblock() throws {
        let h = BlockingHarness()
        h.settings.blockAllPreventsAppDelete = true

        h.blockAll()
        #expect(h.appDeletionBlocked)

        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.fifteenMinutes)
        #expect(!h.appDeletionBlocked)

        h.wake(at: h.at(10, 15))
        #expect(h.appDeletionBlocked)

        h.unblockAllPermanently()
        #expect(!h.appDeletionBlocked)
    }

    @Test func appStaysDeletableWheneverNothingIsBlocked() throws {
        let h = BlockingHarness()
        h.settings.blockAllPreventsAppDelete = true

        h.blockAll()
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.fifteenMinutes)
        #expect(h.blocked.isEmpty && !h.appDeletionBlocked)

        h.blockAllNow()
        #expect(h.appDeletionBlocked)

        h.unblockAllPermanently()
        #expect(h.blocked.isEmpty && !h.appDeletionBlocked)
    }

    @Test func customDomainsFollowTheSameRulesAndTheFeatureToggle() throws {
        let h = BlockingHarness(customDomains: ["a.com", "b.com"])
        h.blockAll()
        try h.addSchedule([], domains: ["a.com"], from: (12, 0), minutes: 60, block: false)
        #expect(h.blockedDomains == ["a.com", "b.com"])

        h.wake(at: h.at(12, 30))
        #expect(h.blockedDomains == ["b.com"])

        h.store.setCustomDomainsEnabled(false)
        h.wake(at: h.at(12, 31))
        #expect(h.blockedDomains.isEmpty)
    }

    @Test func everyActionAndWakeUpWritesTheSameResultTwice() throws {
        let h = BlockingHarness()
        h.blockAll()
        try h.addSchedule([1], from: (12, 0), minutes: 180, block: false)
        try h.addSchedule([4], from: (13, 0), minutes: 60, block: true)

        for minute in stride(from: 0, through: 24 * 60, by: 7) {
            let time = h.at(0).addingTimeInterval(TimeInterval(minute * 60))
            h.wake(at: time)
            let first = h.blocked
            h.openApp(at: time)
            #expect(h.blocked == first)
        }
    }

    @Test func appSelectEditsDuringTimedUnblockAllApplyAtExpiry() throws {
        let h = BlockingHarness()
        h.blockAll()
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)

        h.passTime(to: h.at(10, 5))
        h.timedUnblock.updateMainSelection(TokenFixtures.selection(apps: [1, 2, 4]), screenTimeService: h.screenTime)
        #expect(h.blocked.isEmpty)

        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 4))
    }

    @Test func appSelectEditsKeepAPartialStateDuringTimedUnblockAll() throws {
        let h = BlockingHarness()
        h.blockAll()
        h.unblockGroupPermanently(h.group([3]))
        h.passTime(to: h.at(10))
        try h.unblockAllTimed(.thirtyMinutes)

        h.passTime(to: h.at(10, 5))
        h.timedUnblock.updateMainSelection(TokenFixtures.selection(apps: [1, 2, 3, 4]), screenTimeService: h.screenTime)

        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 4))
    }

    @Test func renamingARunningScheduleDoesNotCancelPermanentUnblockAll() throws {
        let h = BlockingHarness()
        let work = try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        h.wake(at: h.at(9, 30))
        h.passTime(to: h.at(10))
        h.unblockAllPermanently()

        h.passTime(to: h.at(11))
        work.name = "Renamed"
        try h.scheduleService.syncAndPersist(work, allSchedules: h.schedules, screenTimeService: h.screenTime)
        #expect(h.blocked.isEmpty)
    }

    @Test func changingARunningScheduleAppliesItAgain() throws {
        let h = BlockingHarness()
        let work = try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        h.passTime(to: h.at(10))
        h.unblockAllPermanently()

        h.passTime(to: h.at(11))
        work.selection = TokenFixtures.selection(apps: [1, 2])
        try h.scheduleService.syncAndPersist(work, allSchedules: h.schedules, screenTimeService: h.screenTime)
        #expect(h.blocked == h.apps(1, 2))
    }

    @Test func reEnablingAScheduleAfterEmergencyUnblockAppliesImmediately() throws {
        let h = BlockingHarness()
        let work = try h.addSchedule([1], from: (9, 0), minutes: 480, block: true)
        h.wake(at: h.at(9, 30))
        let heartbeat = SharedConstants.reblockHeartbeatActivityName

        h.passTime(to: h.at(10))
        h.emergencyUnblock()
        #expect(h.blocked.isEmpty)
        #expect(!h.activity.monitoredActivityNames.contains(heartbeat))

        h.passTime(to: h.at(11))
        try h.toggle(work)
        #expect(h.blocked == h.apps(1))
        #expect(h.activity.monitoredActivityNames.contains(heartbeat))
    }

    @Test func categoriesAndWebDomainsFollowTheSameRules() throws {
        let h = BlockingHarness()
        h.screenTime.blockAll(
            selection: TokenFixtures.selection(apps: [], categories: [1, 2], webDomains: [3]),
            blockAllPreventsAppDelete: false
        )
        let lunch = BlockSchedule(
            name: "Lunch", selection: TokenFixtures.selection(apps: [], categories: [1], webDomains: [3]),
            startHour: 12, startMinute: 0, durationMinutes: 60, weekdays: Set(1 ... 7),
            shouldBlock: false, isTimed: true, isEnabled: true
        )
        try h.scheduleService.syncAndPersist(lunch, allSchedules: [lunch], screenTimeService: h.screenTime)

        h.wake(at: h.at(12, 30))
        #expect(h.shields.currentShields().categories == [TokenFixtures.category(2)])
        #expect(h.shields.currentShields().webDomains.isEmpty)
        h.wake(at: h.at(13))
        #expect(h.shields.currentShields().categories == [TokenFixtures.category(1), TokenFixtures.category(2)])
        #expect(h.shields.currentShields().webDomains == [TokenFixtures.webDomain(3)])
    }

    @Test func backToBackBlockSchedulesHandOverAtTheSameMinute() throws {
        let h = BlockingHarness(mainApps: Array(1 ... 10), startingAt: 20)
        let weekday = { Calendar.current.component(.weekday, from: h.at(12, dayOffset: $0)) }
        try h.addSchedule(Array(1 ... 10), from: (21, 0), minutes: 480, block: true, weekdays: [weekday(0), weekday(1)])
        try h.addSchedule(Array(3 ... 10), from: (5, 0), minutes: 720, block: true, weekdays: [weekday(1)])

        h.wake(at: h.at(21, 30))
        #expect(h.blocked == Set((1 ... 10).map(TokenFixtures.app)))
        h.wake(at: h.at(5, 0, dayOffset: 1))
        #expect(h.blocked == Set((3 ... 10).map(TokenFixtures.app)))
        h.wake(at: h.at(12, 44, dayOffset: 1))
        #expect(h.blocked == Set((3 ... 10).map(TokenFixtures.app)))
        h.wake(at: h.at(17, 30, dayOffset: 1))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(21, 30, dayOffset: 1))
        #expect(h.blocked == Set((1 ... 10).map(TokenFixtures.app)))
    }
}
