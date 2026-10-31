import FamilyControls
import Foundation
import ManagedSettings
@testable import Normal
import Testing

struct ShieldResolverTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(day: Int = 5, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2024, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func schedule(
        apps: [UInt8],
        domains: [String] = [],
        start: (Int, Int),
        minutes: Int,
        block: Bool,
        timed: Bool = true,
        weekdays: Set<Int> = Set(1 ... 7),
        activatedAt: Date? = nil
    ) throws -> ScheduleDTO {
        try ScheduleDTO(
            id: UUID(),
            name: "S",
            selectionData: TokenFixtures.selection(apps: apps).toData(),
            startHour: start.0,
            startMinute: start.1,
            durationMinutes: minutes,
            weekdays: weekdays,
            shouldBlock: block,
            isTimed: timed,
            customDomains: domains,
            activatedAt: activatedAt
        )
    }

    private func timedUnblock(
        apps: [UInt8],
        group: Bool,
        startDate: Date? = nil,
        endDate: Date
    ) throws -> TimedUnblockDTO {
        try TimedUnblockDTO(
            id: group ? UUID().uuidString : TimedUnblockService.mainID,
            selectionData: TokenFixtures.selection(apps: apps).toData(),
            endDate: endDate,
            activityName: "timedUnblock",
            isGroupUnblock: group,
            startDate: startDate
        )
    }

    private func manual(blocking apps: [UInt8], domains: [String] = [], at date: Date = .distantPast) -> ManualBlockState {
        var state = ManualBlockState()
        state.blockAll(TokenFixtures.selection(apps: apps), customDomains: domains, at: date)
        return state
    }

    private func blockedApps(
        _ manual: ManualBlockState,
        _ schedules: [ScheduleDTO] = [],
        unblocks: [TimedUnblockDTO] = [],
        at date: Date
    ) -> Set<ApplicationToken> {
        ShieldResolver.plan(
            manual: manual,
            enabledSchedules: schedules,
            timedUnblocks: unblocks,
            customDomainsEnabled: true,
            at: date,
            calendar: cal
        ).applications
    }

    private func apps(_ ids: UInt8...) -> Set<ApplicationToken> {
        Set(ids.map(TokenFixtures.app))
    }

    @Test func manualBlockAllShieldsExactlyTheSelection() {
        #expect(blockedApps(manual(blocking: [1, 2]), at: at(12)) == apps(1, 2))
    }

    @Test func unblockWindowLiftsManualBlockAndReblocksAtEnd() throws {
        let mail = try schedule(apps: [1], start: (12, 0), minutes: 180, block: false)
        let state = manual(blocking: [1, 2])

        #expect(blockedApps(state, [mail], at: at(11, 59)) == apps(1, 2))
        #expect(blockedApps(state, [mail], at: at(13)) == apps(2))
        #expect(blockedApps(state, [mail], at: at(15)) == apps(1, 2))
    }

    @Test func simultaneousEndsBothReblock() throws {
        let mail = try schedule(apps: [1], start: (12, 0), minutes: 180, block: false)
        let beeper = try schedule(apps: [2], start: (12, 0), minutes: 180, block: false)
        let state = manual(blocking: [1, 2, 3])

        #expect(blockedApps(state, [mail, beeper], at: at(14)) == apps(3))
        #expect(blockedApps(state, [mail, beeper], at: at(15, 0)) == apps(1, 2, 3))
    }

    @Test func overlappingWindowsLatestStartWins() throws {
        let block = try schedule(apps: [1], start: (5, 0), minutes: 60, block: true)
        let allow = try schedule(apps: [1], start: (5, 30), minutes: 60, block: false)
        let state = ManualBlockState()

        #expect(blockedApps(state, [block, allow], at: at(5, 15)) == apps(1))
        #expect(blockedApps(state, [block, allow], at: at(5, 45)).isEmpty)
        #expect(blockedApps(state, [block, allow], at: at(6, 15)).isEmpty)
    }

    @Test func nestedUnblockWindowIsAnException() throws {
        let workday = try schedule(apps: [1], start: (9, 0), minutes: 480, block: true)
        let lunch = try schedule(apps: [1], start: (12, 0), minutes: 60, block: false)
        let state = ManualBlockState()

        #expect(blockedApps(state, [workday, lunch], at: at(10)) == apps(1))
        #expect(blockedApps(state, [workday, lunch], at: at(12, 30)).isEmpty)
        #expect(blockedApps(state, [workday, lunch], at: at(13, 30)) == apps(1))
        #expect(blockedApps(state, [workday, lunch], at: at(17, 30)).isEmpty)
    }

    @Test func identicalStartsBlockWins() throws {
        let block = try schedule(apps: [1], start: (12, 0), minutes: 60, block: true)
        let allow = try schedule(apps: [1], start: (12, 0), minutes: 120, block: false)

        #expect(blockedApps(ManualBlockState(), [allow, block], at: at(12, 30)) == apps(1))
        #expect(blockedApps(ManualBlockState(), [allow, block], at: at(13, 30)).isEmpty)
    }

    @Test func schedulesOnlyAffectTheirOwnApps() throws {
        let block = try schedule(apps: [1], start: (12, 0), minutes: 60, block: true)
        let allow = try schedule(apps: [2], start: (12, 30), minutes: 60, block: false)

        #expect(blockedApps(manual(blocking: [2]), [block, allow], at: at(12, 45)) == apps(1))
    }

    @Test func manualActionAfterWindowStartWinsUntilNextStart() throws {
        let mail = try schedule(apps: [1], start: (12, 0), minutes: 180, block: false)
        var state = manual(blocking: [2])
        state.block(TokenFixtures.selection(apps: [1]), customDomains: [], at: at(13))

        #expect(blockedApps(state, [mail], at: at(13, 30)) == apps(1, 2))
        #expect(blockedApps(state, [mail], at: at(15, 30)) == apps(1, 2))
        #expect(blockedApps(state, [mail], at: at(day: 6, 12, 30)) == apps(2))
    }

    @Test func permanentUnblockAllSuppressesRunningBlockWindowUntilNextStart() throws {
        let workday = try schedule(apps: [1], start: (9, 0), minutes: 480, block: true)
        var state = manual(blocking: [1, 2])
        state.unblockAll(at: at(10))

        #expect(blockedApps(state, [workday], at: at(11)).isEmpty)
        #expect(blockedApps(state, [workday], at: at(day: 6, 9, 30)) == apps(1))
    }

    @Test func untimedScheduleHoldsUntilSuperseded() throws {
        let permanent = try schedule(apps: [1], start: (9, 0), minutes: 15, block: true, timed: false)
        var state = ManualBlockState()

        #expect(blockedApps(state, [permanent], at: at(8)) == apps(1))
        #expect(blockedApps(state, [permanent], at: at(20)) == apps(1))

        state.unblock(TokenFixtures.selection(apps: [1]), customDomains: [], at: at(21))
        #expect(blockedApps(state, [permanent], at: at(22)).isEmpty)
        #expect(blockedApps(state, [permanent], at: at(day: 6, 9, 1)) == apps(1))
    }

    @Test func timedScheduleActivatedMidWindowBeatsEarlierManualAction() throws {
        let workday = try schedule(apps: [1], start: (9, 0), minutes: 480, block: true, activatedAt: at(13))
        var state = ManualBlockState()
        state.unblockAll(at: at(10))

        #expect(blockedApps(state, [workday], at: at(13, 1)) == apps(1))
    }

    @Test func untimedScheduleIgnoresStartsBeforeItWasActivated() throws {
        let permanent = try schedule(apps: [1], start: (9, 0), minutes: 15, block: true, timed: false, activatedAt: at(8))

        #expect(blockedApps(ManualBlockState(), [permanent], at: at(8, 30)).isEmpty)
        #expect(blockedApps(ManualBlockState(), [permanent], at: at(9, 1)) == apps(1))
    }

    @Test func untimedScheduleActivatedDuringItsStartWindowApplies() throws {
        let permanent = try schedule(apps: [1], start: (9, 0), minutes: 15, block: true, timed: false, activatedAt: at(9, 5))

        #expect(blockedApps(ManualBlockState(), [permanent], at: at(9, 6)) == apps(1))
        #expect(blockedApps(ManualBlockState(), [permanent], at: at(20)) == apps(1))
    }

    @Test func overnightWindowCountsFromPreviousDayStart() throws {
        let night = try schedule(apps: [1], start: (22, 0), minutes: 480, block: true, weekdays: [4])

        #expect(blockedApps(ManualBlockState(), [night], at: at(day: 6, 2)) == apps(1))
        #expect(blockedApps(ManualBlockState(), [night], at: at(day: 6, 7)).isEmpty)
    }

    @Test func mainTimedUnblockLiftsEverything() throws {
        let block = try schedule(apps: [3], start: (12, 0), minutes: 60, block: true)
        let unblock = try timedUnblock(apps: [1, 2], group: false, endDate: at(12, 30))

        #expect(blockedApps(manual(blocking: [1, 2]), [block], unblocks: [unblock], at: at(12, 15)).isEmpty)
        #expect(blockedApps(manual(blocking: [1, 2]), [block], unblocks: [unblock], at: at(12, 30)) == apps(1, 2, 3))
    }

    private func hiddenApps(
        _ manual: ManualBlockState,
        unblocks: [TimedUnblockDTO] = [],
        at date: Date
    ) -> Set<ApplicationToken> {
        ShieldResolver.plan(
            manual: manual,
            enabledSchedules: [],
            timedUnblocks: unblocks,
            customDomainsEnabled: true,
            hideBlockedAppsEnabled: true,
            at: date,
            calendar: cal
        ).hiddenApplications
    }

    @Test func hiddenAppsReappearDuringGroupTimedUnblock() throws {
        let unblock = try timedUnblock(apps: [2], group: true, endDate: at(12, 30))

        #expect(hiddenApps(manual(blocking: [1, 2]), unblocks: [unblock], at: at(12, 15)) == apps(1))
        #expect(hiddenApps(manual(blocking: [1, 2]), unblocks: [unblock], at: at(12, 30)) == apps(1, 2))
    }

    @Test func hiddenAppsReappearDuringMainTimedUnblock() throws {
        let unblock = try timedUnblock(apps: [1, 2], group: false, endDate: at(12, 30))

        #expect(hiddenApps(manual(blocking: [1, 2]), unblocks: [unblock], at: at(12, 15)).isEmpty)
        #expect(hiddenApps(manual(blocking: [1, 2]), unblocks: [unblock], at: at(12, 30)) == apps(1, 2))
    }

    @Test func categoryBlocksAreNotHidden() {
        var state = ManualBlockState()
        state.blockAll(TokenFixtures.selection(apps: [1], categories: [2]), customDomains: [], at: .distantPast)

        let plan = ShieldResolver.plan(
            manual: state,
            enabledSchedules: [],
            timedUnblocks: [],
            customDomainsEnabled: true,
            hideBlockedAppsEnabled: true,
            at: at(12),
            calendar: cal
        )

        #expect(plan.categories == [TokenFixtures.category(2)])
        #expect(plan.hiddenApplications == apps(1))
    }

    @Test func timedUnblockAllRestoresManualStateIncludingBlocksMadeDuringIt() throws {
        var state = manual(blocking: [1, 2, 3], at: at(8))
        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(9))
        let unblockAll = try timedUnblock(apps: [1, 2, 3], group: false, startDate: at(10), endDate: at(10, 30))
        let lateBlock = try schedule(apps: [4], start: (10, 20), minutes: 40, block: true)

        #expect(blockedApps(state, [lateBlock], unblocks: [unblockAll], at: at(10, 5)).isEmpty)

        state.block(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(10, 10))
        #expect(blockedApps(state, [lateBlock], unblocks: [unblockAll], at: at(10, 15)) == apps(3))
        #expect(blockedApps(state, [lateBlock], unblocks: [unblockAll], at: at(10, 25)) == apps(3))
        #expect(blockedApps(state, [lateBlock], unblocks: [unblockAll], at: at(10, 30)) == apps(1, 2, 3, 4))
    }

    @Test func timedUnblockAllWithoutLaterActionsRestoresPartialState() throws {
        var state = manual(blocking: [1, 2, 3], at: at(8))
        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(9))
        let unblockAll = try timedUnblock(apps: [1, 2, 3], group: false, startDate: at(10), endDate: at(10, 30))

        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 15)).isEmpty)
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 30)) == apps(1, 2))
    }

    @Test func blockAllDuringTimedUnblockAllBlocksEverythingNowAndAfter() throws {
        var state = manual(blocking: [1, 2, 3], at: at(8))
        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(9))
        let unblockAll = try timedUnblock(apps: [1, 2, 3], group: false, startDate: at(10), endDate: at(10, 30))

        state.blockAll(TokenFixtures.selection(apps: [1, 2, 3]), customDomains: [], at: at(10, 10))
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 15)) == apps(1, 2, 3))
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 30)) == apps(1, 2, 3))
    }

    @Test func reblockThenTimedUnblockDuringTimedUnblockAll() throws {
        var state = manual(blocking: [1, 2, 3], at: at(8))
        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(9))
        let unblockAll = try timedUnblock(apps: [1, 2, 3], group: false, startDate: at(10), endDate: at(10, 30))
        state.block(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(10, 5))
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 7)) == apps(3))

        let unblockC = try timedUnblock(apps: [3], group: true, startDate: at(10, 10), endDate: at(10, 25))
        let unblocks = [unblockAll, unblockC]
        #expect(blockedApps(state, unblocks: unblocks, at: at(10, 15)).isEmpty)
        #expect(blockedApps(state, unblocks: unblocks, at: at(10, 25)) == apps(3))
        #expect(blockedApps(state, unblocks: unblocks, at: at(10, 30)) == apps(1, 2, 3))
    }

    @Test func reblockThenPermanentUnblockDuringTimedUnblockAll() throws {
        var state = manual(blocking: [1, 2, 3], at: at(8))
        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(9))
        let unblockAll = try timedUnblock(apps: [1, 2, 3], group: false, startDate: at(10), endDate: at(10, 30))
        state.block(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(10, 5))
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 7)) == apps(3))

        state.unblock(TokenFixtures.selection(apps: [3]), customDomains: [], at: at(10, 10))
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 15)).isEmpty)
        #expect(blockedApps(state, unblocks: [unblockAll], at: at(10, 30)) == apps(1, 2))
    }

    @Test func groupTimedUnblockBeatsBlockWindowUntilExpiry() throws {
        let block = try schedule(apps: [1, 2], start: (12, 0), minutes: 60, block: true)
        let unblock = try timedUnblock(apps: [1], group: true, endDate: at(12, 30))

        #expect(blockedApps(ManualBlockState(), [block], unblocks: [unblock], at: at(12, 15)) == apps(2))
        #expect(blockedApps(ManualBlockState(), [block], unblocks: [unblock], at: at(12, 45)) == apps(1, 2))
    }

    @Test func customDomainsResolveOnlyWhenEnabled() throws {
        let allow = try schedule(apps: [], domains: ["a.com"], start: (12, 0), minutes: 60, block: false)
        let state = manual(blocking: [], domains: ["a.com", "b.com"])

        let enabled = ShieldResolver.plan(
            manual: state, enabledSchedules: [allow], timedUnblocks: [],
            customDomainsEnabled: true, at: at(12, 30), calendar: cal
        )
        let disabled = ShieldResolver.plan(
            manual: state, enabledSchedules: [allow], timedUnblocks: [],
            customDomainsEnabled: false, at: at(12, 30), calendar: cal
        )
        #expect(enabled.customDomains == ["b.com"])
        #expect(disabled.customDomains.isEmpty)
    }

    @Test func manualStateRoundTripsThroughPropertyList() throws {
        var state = manual(blocking: [1, 2], domains: ["a.com"], at: at(9))
        state.unblock(TokenFixtures.selection(apps: [2]), customDomains: [], at: at(10))

        let data = try PropertyListEncoder().encode(state)
        #expect(try PropertyListDecoder().decode(ManualBlockState.self, from: data) == state)
    }

    @Test func migrationRepairsUnblockScheduleAppsAndKeepsRunningWindow() throws {
        let mail = try schedule(apps: [1], start: (12, 0), minutes: 180, block: false)
        var shielded = ShieldPlan()
        shielded.applications = apps(2)

        let state = ShieldResolver.migratedManualState(
            shielded: shielded, enabledSchedules: [mail], timedUnblocks: [],
            scheduleOverrideActive: false, scheduleOverrideSince: nil, at: at(13)
        )

        #expect(blockedApps(state, [mail], at: at(13)) == apps(2))
        #expect(blockedApps(state, [mail], at: at(15)) == apps(1, 2))
    }

    @Test func migrationKeepsRunningBlockScheduleAppsBlockedAfterWindow() throws {
        let block = try schedule(apps: [1], start: (12, 0), minutes: 60, block: true)
        var shielded = ShieldPlan()
        shielded.applications = apps(1)

        let state = ShieldResolver.migratedManualState(
            shielded: shielded, enabledSchedules: [block], timedUnblocks: [],
            scheduleOverrideActive: false, scheduleOverrideSince: nil, at: at(12, 30)
        )

        #expect(blockedApps(state, [block], at: at(13, 30)) == apps(1))
    }

    @Test func migrationRestoresAppsHeldByActiveTimedUnblocks() throws {
        let main = try timedUnblock(apps: [1, 2], group: false, endDate: at(12, 30))
        let group = try timedUnblock(apps: [3], group: true, endDate: at(12, 30))

        let state = ShieldResolver.migratedManualState(
            shielded: ShieldPlan(), enabledSchedules: [], timedUnblocks: [main, group],
            scheduleOverrideActive: false, scheduleOverrideSince: nil, at: at(12)
        )

        #expect(blockedApps(state, unblocks: [main, group], at: at(12, 15)).isEmpty)
        #expect(blockedApps(state, unblocks: [main, group], at: at(12, 30)) == apps(1, 2, 3))
    }

    @Test func migrationOfPermanentUnblockAllSkipsRepairAndSuppressesOlderWindows() throws {
        let mail = try schedule(apps: [1], start: (12, 0), minutes: 180, block: false)
        let workday = try schedule(apps: [2], start: (9, 0), minutes: 480, block: true)

        let state = ShieldResolver.migratedManualState(
            shielded: ShieldPlan(), enabledSchedules: [mail, workday], timedUnblocks: [],
            scheduleOverrideActive: true, scheduleOverrideSince: at(10), at: at(11)
        )

        #expect(blockedApps(state, [mail, workday], at: at(11)).isEmpty)
        #expect(blockedApps(state, [mail, workday], at: at(15, 30)).isEmpty)
        #expect(blockedApps(state, [mail, workday], at: at(day: 6, 9, 30)) == apps(2))
    }

    private func newYork() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    @Test func windowsEndOnTheWallClockAcrossDaylightSavingChanges() throws {
        let ny = newYork()
        let night = try schedule(apps: [1], start: (22, 0), minutes: 540, block: true)
        func local(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            ny.date(from: DateComponents(year: 2024, month: month, day: day, hour: hour, minute: minute))!
        }
        func blocked(_ date: Date) -> Bool {
            !ShieldResolver.plan(
                manual: ManualBlockState(), enabledSchedules: [night], timedUnblocks: [],
                customDomainsEnabled: false, at: date, calendar: ny
            ).applications.isEmpty
        }

        #expect(blocked(local(3, 10, 6, 45)))
        #expect(!blocked(local(3, 10, 7, 15)))
        #expect(blocked(local(11, 3, 6, 30)))
        #expect(!blocked(local(11, 3, 7, 15)))
    }

    @Test func scheduleOrderDoesNotMatter() throws {
        let block = try schedule(apps: [1], start: (5, 0), minutes: 60, block: true)
        let allow = try schedule(apps: [1], start: (5, 30), minutes: 60, block: false)
        let sameStart = try schedule(apps: [2], start: (5, 30), minutes: 60, block: true)
        let sameStartAllow = try schedule(apps: [2], start: (5, 30), minutes: 30, block: false)

        for schedules in [[block, allow, sameStart, sameStartAllow], [sameStartAllow, sameStart, allow, block]] {
            #expect(blockedApps(ManualBlockState(), schedules, at: at(5, 15)) == apps(1))
            #expect(blockedApps(ManualBlockState(), schedules, at: at(5, 45)) == apps(2))
        }
    }

    @Test func manualUnblockAtExactlyTheWindowStartLosesTheTie() throws {
        let block = try schedule(apps: [1], start: (9, 0), minutes: 60, block: true)
        var state = ManualBlockState()
        state.unblock(TokenFixtures.selection(apps: [1]), customDomains: [], at: at(9))

        #expect(blockedApps(state, [block], at: at(9, 30)) == apps(1))
    }

    @Test func overnightWindowCrossesIntoTheNextWeekday() throws {
        let saturdayNight = try schedule(apps: [1], start: (22, 0), minutes: 480, block: true, weekdays: [7])

        #expect(blockedApps(ManualBlockState(), [saturdayNight], at: at(day: 8, 23)) == apps(1))
        #expect(blockedApps(ManualBlockState(), [saturdayNight], at: at(day: 9, 2)) == apps(1))
        #expect(blockedApps(ManualBlockState(), [saturdayNight], at: at(day: 9, 6)).isEmpty)
        #expect(blockedApps(ManualBlockState(), [saturdayNight], at: at(day: 9, 22, 30)).isEmpty)
    }

    @Test func categoryAndWebDomainTokensResolveIndependently() throws {
        var state = ManualBlockState()
        state.blockAll(TokenFixtures.selection(apps: [1], categories: [1], webDomains: [1]), customDomains: [], at: .distantPast)
        let allow = try ScheduleDTO(
            id: UUID(), name: "S", selectionData: TokenFixtures.selection(apps: [], categories: [1]).toData(),
            startHour: 12, startMinute: 0, durationMinutes: 60, weekdays: Set(1 ... 7),
            shouldBlock: false, isTimed: true
        )

        let plan = ShieldResolver.plan(
            manual: state, enabledSchedules: [allow], timedUnblocks: [],
            customDomainsEnabled: false, at: at(12, 30), calendar: cal
        )
        #expect(plan.applications == apps(1))
        #expect(plan.categories.isEmpty)
        #expect(plan.webDomains == [TokenFixtures.webDomain(1)])
    }
}
