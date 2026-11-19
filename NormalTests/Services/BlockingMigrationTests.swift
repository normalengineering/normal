import FamilyControls
import Foundation
import ManagedSettings
import Testing

@testable import Normal

@MainActor
struct BlockingMigrationTests {
    private func legacyShields(_ h: BlockingHarness, apps: [UInt8], domains: [String] = [], deny: Bool = false) {
        var plan = ShieldPlan()
        plan.applications = Set(apps.map(TokenFixtures.app))
        plan.customDomains = Set(domains)
        plan.denyAppRemoval = deny
        h.shields.apply(plan)
    }

    private func legacySchedule(
        _ h: BlockingHarness,
        apps: [UInt8],
        from start: (Int, Int),
        minutes: Int,
        block: Bool,
        timed: Bool = true,
        monitored: Bool = true
    ) throws -> ScheduleDTO {
        let dto = try ScheduleDTO(
            id: UUID(),
            name: "Legacy",
            selectionData: TokenFixtures.selection(apps: apps).toData(),
            startHour: start.0,
            startMinute: start.1,
            durationMinutes: minutes,
            weekdays: Set(1...7),
            shouldBlock: block,
            isTimed: timed
        )
        h.store.schedules.append(dto)
        if monitored {
            h.activity.monitoredActivityNames.insert(SharedConstants.scheduleActivityName(for: dto.id))
        }
        return dto
    }

    private func legacyTimedUnblock(
        _ h: BlockingHarness,
        apps: [UInt8],
        group: Bool,
        endDate: Date,
        preventsAppDelete: Bool? = nil
    ) throws {
        try h.store.timedUnblocks.append(
            TimedUnblockDTO(
                id: group ? UUID().uuidString : TimedUnblockService.mainID,
                selectionData: TokenFixtures.selection(apps: apps).toData(),
                endDate: endDate,
                activityName: group ? "timedUnblock_group" : SharedConstants.mainTimedUnblockActivityName,
                isGroupUnblock: group,
                blockAllPreventsAppDelete: preventsAppDelete
            ))
    }

    @Test func existingShieldsCarryOverUnchangedWhenNoWindowIsOpen() {
        let h = BlockingHarness()
        legacyShields(h, apps: [1, 2], deny: true)

        h.wake(at: h.at(8))

        #expect(h.blocked == h.apps(1, 2))
        #expect(h.appDeletionBlocked)
        #expect(h.store.manualBlockState != nil)
    }

    @Test func migrationRunsOnceAndThenRepairsStaleWrites() {
        let h = BlockingHarness()
        legacyShields(h, apps: [1, 2])
        h.wake(at: h.at(8))

        legacyShields(h, apps: [1])
        h.wake(at: h.at(8, 5))

        #expect(h.blocked == h.apps(1, 2))
    }

    @Test func stuckUnblockScheduleAppIsRepaired() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [2, 3])
        _ = try legacySchedule(h, apps: [1], from: (12, 0), minutes: 180, block: false)

        h.wake(at: h.at(17, 25))

        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func unblockWindowOpenAtMigrationStaysOpenThenReblocks() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [2, 3])
        _ = try legacySchedule(h, apps: [1], from: (12, 0), minutes: 180, block: false)

        h.wake(at: h.at(13))
        #expect(h.blocked == h.apps(2, 3))
        h.wake(at: h.at(15))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func blockWindowOpenAtMigrationFailsClosed() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [1])
        _ = try legacySchedule(h, apps: [1], from: (9, 0), minutes: 480, block: true)

        h.wake(at: h.at(10))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(17, 30))
        #expect(h.blocked == h.apps(1))

        h.unblockGroupPermanently(h.group([1]))
        #expect(h.blocked.isEmpty)
    }

    @Test func permanentUnblockAllOverrideIsHonoured() throws {
        let h = BlockingHarness()
        _ = try legacySchedule(h, apps: [1], from: (9, 0), minutes: 480, block: true)
        _ = try legacySchedule(h, apps: [2], from: (12, 0), minutes: 60, block: false)
        h.store.scheduleOverrideActive = true
        h.store.scheduleOverrideSince = h.at(10)

        h.wake(at: h.at(11))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(13, 30))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(9, 30, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func legacyOverrideWithoutTimestampSuppressesTheRunningWindow() throws {
        let h = BlockingHarness()
        _ = try legacySchedule(h, apps: [1], from: (9, 0), minutes: 480, block: true)
        h.store.scheduleOverrideActive = true

        h.wake(at: h.at(11))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(9, 30, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func mainTimedUnblockWithoutStartDateExpiresIntoTheMainList() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [], deny: false)
        try legacyTimedUnblock(h, apps: [1, 2, 3], group: false, endDate: h.at(10, 30), preventsAppDelete: true)

        h.wake(at: h.at(10))
        #expect(h.blocked.isEmpty)
        #expect(!h.appDeletionBlocked)

        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 3))
        #expect(h.appDeletionBlocked)
    }

    @Test func groupTimedUnblockAtMigrationReblocksAtExpiry() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [2, 3])
        try legacyTimedUnblock(h, apps: [1], group: true, endDate: h.at(10, 30))

        h.wake(at: h.at(10))
        #expect(h.blocked == h.apps(2, 3))
        h.wake(at: h.at(10, 30))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func schedulesWithoutEnabledFlagFallBackToMonitoredActivities() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [3])
        _ = try legacySchedule(h, apps: [1], from: (12, 0), minutes: 60, block: false, monitored: true)
        _ = try legacySchedule(h, apps: [2], from: (12, 0), minutes: 60, block: false, monitored: false)

        h.wake(at: h.at(8))

        #expect(h.blocked == h.apps(1, 3))
    }

    @Test func firstAppLaunchMigratesBeforeReRegisteringSchedules() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [2, 3])
        let mail = BlockSchedule(
            name: "Mail", selection: TokenFixtures.selection(apps: [1]),
            startHour: 12, startMinute: 0, durationMinutes: 180, weekdays: Set(1...7),
            shouldBlock: false, isTimed: true, isEnabled: true
        )
        h.store.schedules = [try #require(mail.toDTO())].map {
            ScheduleDTO(
                id: $0.id, name: $0.name, selectionData: $0.selectionData,
                startHour: $0.startHour, startMinute: $0.startMinute, durationMinutes: $0.durationMinutes,
                weekdays: $0.weekdays, shouldBlock: $0.shouldBlock, isTimed: $0.isTimed
            )
        }
        h.activity.monitoredActivityNames.insert(SharedConstants.scheduleActivityName(for: mail.id))

        h.clock.now = h.at(13)
        h.timedUnblock.reconcile(screenTimeService: h.screenTime)
        h.scheduleService.registerAll([mail], screenTimeService: h.screenTime)

        #expect(h.blocked == h.apps(2, 3))
        h.wake(at: h.at(15))
        #expect(h.blocked == h.apps(1, 2, 3))
    }

    @Test func legacyCustomDomainFilterCarriesOver() {
        let h = BlockingHarness(customDomains: ["b.com"])
        legacyShields(h, apps: [1], domains: ["b.com"])

        h.wake(at: h.at(8))

        #expect(h.blocked == h.apps(1))
        #expect(h.blockedDomains == ["b.com"])
    }

    @Test func manualStatePersistsThroughTheRealSharedStore() throws {
        let defaults = try #require(UserDefaults(suiteName: "manual-\(UUID().uuidString)"))
        let store = SharedStore(defaults: defaults)
        var state = ManualBlockState()
        state.blockAll(TokenFixtures.selection(apps: [1, 2]), customDomains: ["A.com"], at: Date(timeIntervalSince1970: 100))
        state.setAppDeletionBlocked(true, at: Date(timeIntervalSince1970: 100))

        store.saveManualBlockState(state)

        #expect(store.loadManualBlockState() == state)
        #expect(store.loadManualBlockState()?.customDomains.blockedTokens == ["a.com"])
    }

    @Test func unreadableManualStateIsTreatedAsMissing() throws {
        let defaults = try #require(UserDefaults(suiteName: "manual-\(UUID().uuidString)"))
        defaults.set(Data("garbage".utf8), forKey: SharedConstants.DefaultsKey.manualBlockState)

        #expect(SharedStore(defaults: defaults).loadManualBlockState() == nil)
    }

    @Test func legacyUntimedUnblockScheduleDoesNotOverrideALaterBlock() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [1, 2])
        _ = try legacySchedule(h, apps: [1], from: (6, 0), minutes: 15, block: false, timed: false)

        h.wake(at: h.at(8))
        #expect(h.blocked == h.apps(1, 2))

        h.wake(at: h.at(6, 1, dayOffset: 1))
        #expect(h.blocked == h.apps(2))
    }

    @Test func legacyUntimedBlockScheduleDoesNotReblockALaterUnblock() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [])
        _ = try legacySchedule(h, apps: [1], from: (6, 0), minutes: 15, block: true, timed: false)

        h.wake(at: h.at(8))
        #expect(h.blocked.isEmpty)

        h.wake(at: h.at(6, 1, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func appsBlockedAfterALegacyOverrideBeatOlderWindows() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [1])
        _ = try legacySchedule(h, apps: [1], from: (9, 0), minutes: 180, block: false)
        h.store.scheduleOverrideActive = true
        h.store.scheduleOverrideSince = h.at(10)

        h.wake(at: h.at(11))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(9, 30, dayOffset: 1))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(12, 0, dayOffset: 1))
        #expect(h.blocked == h.apps(1))
    }

    @Test func expiredTimedUnblockThatNeverReblockedIsRestoredOnFirstLaunch() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [], deny: false)
        try legacyTimedUnblock(h, apps: [1, 2, 3], group: false, endDate: h.at(7), preventsAppDelete: true)

        h.openApp(at: h.at(8))

        #expect(h.blocked == h.apps(1, 2, 3))
        #expect(h.appDeletionBlocked)
        #expect(h.store.timedUnblocks.isEmpty)
    }

    @Test func manualRecordDoesNotDependOnDictionaryEncoding() throws {
        var state = ManualBlockState()
        state.blockAll(TokenFixtures.selection(apps: [1, 2]), customDomains: ["a.com"], at: Date(timeIntervalSince1970: 50))
        let plist =
            try PropertyListSerialization.propertyList(
                from: PropertyListEncoder().encode(state), format: nil
            ) as? [String: Any]
        let applications = plist?["applications"] as? [String: Any]

        #expect(applications?["entries"] is [[String: Any]])
    }

    @Test func nestedUnblockInsideABlockScheduleIsNotRepairedIntoAPermanentBlock() throws {
        let h = BlockingHarness()
        legacyShields(h, apps: [])
        _ = try legacySchedule(h, apps: [1], from: (9, 0), minutes: 480, block: true)
        _ = try legacySchedule(h, apps: [1], from: (12, 0), minutes: 60, block: false)

        h.wake(at: h.at(8))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(10))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(12, 30))
        #expect(h.blocked.isEmpty)
        h.wake(at: h.at(13, 30))
        #expect(h.blocked == h.apps(1))
        h.wake(at: h.at(18))
        #expect(h.blocked.isEmpty)
    }

    @Test func unreadableScheduleSelectionIsSkippedDuringMigration() {
        let h = BlockingHarness()
        legacyShields(h, apps: [2])
        h.store.schedules.append(
            ScheduleDTO(
                id: UUID(), name: "Corrupt", selectionData: Data("garbage".utf8),
                startHour: 12, startMinute: 0, durationMinutes: 60, weekdays: Set(1...7),
                shouldBlock: false, isTimed: true, isEnabled: true
            ))

        h.wake(at: h.at(12, 30))

        #expect(h.blocked == h.apps(2))
    }

    @Test func legacyCategoriesCarryOver() {
        let h = BlockingHarness()
        var plan = ShieldPlan()
        plan.categories = [TokenFixtures.category(1)]
        plan.webDomains = [TokenFixtures.webDomain(2)]
        h.shields.apply(plan)

        h.wake(at: h.at(8))

        #expect(h.shields.currentShields().categories == [TokenFixtures.category(1)])
        #expect(h.shields.currentShields().webDomains == [TokenFixtures.webDomain(2)])
    }

    private struct Version15ScheduleDTO: Codable {
        let id: UUID
        let name: String
        let selectionData: Data
        let startHour: Int
        let startMinute: Int
        let durationMinutes: Int
        let weekdays: Set<Int>
        let shouldBlock: Bool
        let isTimed: Bool
        let encodedCustomDomains: [String]?
    }

    private func version15Device(overrideFlag: Bool) throws -> (ScreenTimeService, InMemoryShieldStore, SharedStore) {
        let defaults = try #require(UserDefaults(suiteName: "v15-\(UUID().uuidString)"))
        let mail = try Version15ScheduleDTO(
            id: UUID(), name: "Mail", selectionData: TokenFixtures.selection(apps: [1]).toData(),
            startHour: 12, startMinute: 0, durationMinutes: 180, weekdays: Set(1...7),
            shouldBlock: false, isTimed: true, encodedCustomDomains: nil
        )
        defaults.set(try PropertyListEncoder().encode([mail]), forKey: SharedConstants.DefaultsKey.schedules)
        if overrideFlag {
            defaults.set(true, forKey: SharedConstants.DefaultsKey.scheduleOverride)
        }
        let activity = FakeDeviceActivityCenter()
        activity.monitoredActivityNames.insert(SharedConstants.scheduleActivityName(for: mail.id))
        let shields = InMemoryShieldStore(startBlocked: false)
        var stuck = ShieldPlan()
        stuck.applications = [TokenFixtures.app(2)]
        shields.apply(stuck)
        let store = SharedStore(defaults: defaults)
        let afterWindow = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: .now.addingTimeInterval(86400))!
        let service = ScreenTimeService(
            defaults: defaults, shield: shields, sharedStore: store, activityCenter: activity,
            clock: { afterWindow }
        )
        return (service, shields, store)
    }

    @Test func version15DataMigratesThroughTheRealSharedStore() throws {
        let (service, shields, store) = try version15Device(overrideFlag: false)

        service.reconcile()

        #expect(shields.currentShields().applications == [TokenFixtures.app(1), TokenFixtures.app(2)])
        #expect(store.loadManualBlockState()?.migratedAt != nil)
    }

    @Test func version15PermanentUnblockAllSkipsTheRepairThroughTheRealSharedStore() throws {
        let (service, shields, _) = try version15Device(overrideFlag: true)

        service.reconcile()

        #expect(shields.currentShields().applications == [TokenFixtures.app(2)])
    }
}
