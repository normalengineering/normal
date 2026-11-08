import FamilyControls
import Foundation
import ManagedSettings
@testable import Normal

@MainActor
final class BlockingHarness {
    final class Clock {
        var now: Date

        init(_ now: Date) {
            self.now = now
        }
    }

    let day: Date
    let clock: Clock
    let store = FakeSharedStore()
    let activity = FakeDeviceActivityCenter()
    let shields: InMemoryShieldStore
    let screenTime: ScreenTimeService
    let scheduleService: ScheduleService
    let timedUnblock: TimedUnblockService
    let usageLimits: UsageLimitService
    let settings = Settings()
    let main: SelectedApps
    private(set) var schedules: [BlockSchedule] = []

    init(mainApps: [UInt8] = [1, 2, 3], customDomains: [String] = [], startingAt hour: Int = 8) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        day = Calendar.current.startOfDay(for: tomorrow)
        let clock = Clock(Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!)
        self.clock = clock
        shields = InMemoryShieldStore(startBlocked: false)
        screenTime = ScreenTimeService(
            defaults: UserDefaults(suiteName: "harness-\(UUID().uuidString)")!,
            shield: shields,
            sharedStore: store,
            activityCenter: activity,
            clock: { clock.now }
        )
        scheduleService = ScheduleService(activityCenter: activity, sharedStore: store, clock: { clock.now })
        timedUnblock = TimedUnblockService(
            activityCenter: activity,
            sharedStore: store,
            clock: { clock.now },
            onExpiration: {}
        )
        usageLimits = UsageLimitService(
            activityCenter: activity,
            sharedStore: store,
            ledger: InMemoryUsageLimitLedger(),
            limitShield: InMemoryDailyLimitShield()
        )
        main = SelectedApps(selection: TokenFixtures.selection(apps: mainApps), customDomains: customDomains)
        settings.blockAllPreventsAppDelete = false
        if !customDomains.isEmpty {
            settings.enableCustomDomains = true
            store.setCustomDomainsEnabled(true)
        }
    }

    func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        let target = Calendar.current.date(byAdding: .day, value: dayOffset, to: day)!
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: target)!
    }

    var blocked: Set<ApplicationToken> {
        shields.currentShields().applications
    }

    var blockedDomains: Set<String> {
        shields.currentShields().customDomains
    }

    var appDeletionBlocked: Bool {
        shields.denyAppRemoval
    }

    func apps(_ ids: UInt8...) -> Set<ApplicationToken> {
        Set(ids.map(TokenFixtures.app))
    }

    func passTime(to date: Date) {
        clock.now = date
    }

    func wake(at date: Date) {
        clock.now = date
        screenTime.reconcile()
    }

    func openApp(at date: Date) {
        clock.now = date
        timedUnblock.reconcile(screenTimeService: screenTime)
        scheduleService.registerAll(schedules, screenTimeService: screenTime)
    }

    func blockAll() {
        BlockActions.blockAll(
            mainSelection: main,
            settings: settings,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock
        )
    }

    func unblockAllPermanently() {
        screenTime.unblockAll(blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete)
    }

    func blockGroup(_ group: AppGroup) {
        BlockActions.blockGroup(
            group,
            settings: settings,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock
        )
    }

    func unblockGroupPermanently(_ group: AppGroup) {
        screenTime.unblock(selection: group.selection, customDomains: group.customDomains)
    }

    func unblockAllTimed(_ duration: TimedUnblockDuration) throws {
        try timedUnblock.startMain(
            duration: duration,
            mainSelection: main,
            settings: settings,
            screenTimeService: screenTime
        )
    }

    func unblockGroupTimed(_ group: AppGroup, _ duration: TimedUnblockDuration) throws {
        try timedUnblock.startGroup(
            duration: duration,
            groupId: group.id,
            selection: group.selection,
            customDomains: group.customDomains,
            screenTimeService: screenTime
        )
    }

    func blockAllNow() {
        timedUnblock.cancelMain(
            selection: main.selection,
            customDomains: main.customDomains,
            screenTimeService: screenTime,
            blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
        )
    }

    func emergencyUnblock() {
        BlockActions.emergencyUnblock(
            schedules: schedules,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            scheduleService: scheduleService,
            usageLimitService: usageLimits
        )
    }

    func group(_ apps: [UInt8], domains: [String] = []) -> AppGroup {
        AppGroup(name: "G", selection: TokenFixtures.selection(apps: apps), customDomains: domains)
    }

    @discardableResult
    func addSchedule(
        _ apps: [UInt8],
        domains: [String] = [],
        from start: (Int, Int),
        minutes: Int,
        block: Bool,
        timed: Bool = true,
        weekdays: Set<Int> = Set(1 ... 7)
    ) throws -> BlockSchedule {
        let schedule = BlockSchedule(
            name: "S\(schedules.count)",
            selection: TokenFixtures.selection(apps: apps),
            startHour: start.0,
            startMinute: start.1,
            durationMinutes: minutes,
            weekdays: weekdays,
            shouldBlock: block,
            isTimed: timed,
            isEnabled: true,
            customDomains: domains
        )
        schedules.append(schedule)
        try scheduleService.syncAndPersist(schedule, allSchedules: schedules, screenTimeService: screenTime)
        return schedule
    }

    func toggle(_ schedule: BlockSchedule) throws {
        try scheduleService.toggleEnabled(schedule, allSchedules: schedules, screenTimeService: screenTime)
    }

    func delete(_ schedule: BlockSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        scheduleService.remove(schedule, remaining: schedules, screenTimeService: screenTime)
    }
}
