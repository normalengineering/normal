import DeviceActivity
import FamilyControls
import Foundation
@testable import Normal
import Testing

@MainActor
struct BlockActionsTests {
    private let screenTime = FakeScreenTimeService()
    private let activity = FakeDeviceActivityCenter()
    private let store = FakeSharedStore()

    private func makeTimedUnblock() -> TimedUnblockService {
        TimedUnblockService(activityCenter: activity, sharedStore: store, onExpiration: {})
    }

    private func makeSchedule() -> ScheduleService {
        ScheduleService(activityCenter: activity, sharedStore: store)
    }

    private func makeSettings(customDomains: Bool = false, preventsAppDelete: Bool = true) -> Settings {
        let settings = Settings()
        settings.enableCustomDomains = customDomains
        settings.blockAllPreventsAppDelete = preventsAppDelete
        return settings
    }

    // MARK: - blockAll

    @Test func blockAllAppliesShieldWithGatedDomains() {
        let main = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["example.com"])

        BlockActions.blockAll(
            mainSelection: main,
            settings: makeSettings(customDomains: false, preventsAppDelete: false),
            screenTimeService: screenTime,
            timedUnblockService: makeTimedUnblock(),
            scheduleService: makeSchedule()
        )

        #expect(screenTime.applyShieldOnAllCalled)
        #expect(screenTime.applyShieldOnAllCustomDomains == [])
        #expect(screenTime.applyShieldOnAllBlockAllPreventsAppDelete == false)
    }

    @Test func blockAllIncludesDomainsAndPreventsDeleteWhenEnabled() {
        let main = SelectedApps(selection: FamilyActivitySelection(), customDomains: ["example.com"])

        BlockActions.blockAll(
            mainSelection: main,
            settings: makeSettings(customDomains: true, preventsAppDelete: true),
            screenTimeService: screenTime,
            timedUnblockService: makeTimedUnblock(),
            scheduleService: makeSchedule()
        )

        #expect(screenTime.applyShieldOnAllCustomDomains == ["example.com"])
        #expect(screenTime.applyShieldOnAllBlockAllPreventsAppDelete == true)
    }

    @Test func blockAllEndsTimedUnblocksAndClearsScheduleOverride() throws {
        let timedUnblock = makeTimedUnblock()
        let groupID = UUID()
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: groupID,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        store.scheduleOverrideActive = true

        BlockActions.blockAll(
            mainSelection: SelectedApps(selection: FamilyActivitySelection()),
            settings: makeSettings(),
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            scheduleService: makeSchedule()
        )

        #expect(timedUnblock.activeUnblocks.isEmpty)
        #expect(store.timedUnblocks.isEmpty)
        #expect(!store.scheduleOverrideActive)
    }

    // MARK: - blockGroup

    @Test func blockGroupAddsToShieldsWhenNoTimedUnblock() {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["x.com"])

        BlockActions.blockGroup(
            group,
            settings: makeSettings(customDomains: true),
            screenTimeService: screenTime,
            timedUnblockService: makeTimedUnblock()
        )

        #expect(screenTime.addToShieldsCalled)
        #expect(screenTime.addToShieldsCustomDomains == ["x.com"])
        #expect(activity.stopCalls.isEmpty)
    }

    @Test func blockGroupCancelsActiveTimedUnblock() throws {
        let timedUnblock = makeTimedUnblock()
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection())
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: group.id,
            selection: group.selection,
            screenTimeService: screenTime
        )

        BlockActions.blockGroup(
            group,
            settings: makeSettings(),
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock
        )

        #expect(!timedUnblock.isGroupUnblockActive(groupId: group.id))
        #expect(screenTime.addToShieldsCalled)
        let stopped = activity.stopCalls.flatMap { $0 }.map(\.rawValue)
        #expect(stopped.contains(SharedConstants.groupTimedUnblockActivityName(for: group.id)))
    }

    private func timedUnblockRecord(id: String, activityName: String, endingIn interval: TimeInterval) throws -> TimedUnblockDTO {
        try TimedUnblockDTO(
            id: id,
            selectionData: FamilyActivitySelection().toData(),
            endDate: .now.addingTimeInterval(interval),
            activityName: activityName,
            isGroupUnblock: id != TimedUnblockService.mainID
        )
    }

    private func emergencyUnblock(
        schedules: [BlockSchedule] = [],
        timedUnblock: TimedUnblockService? = nil,
        usageLimit: UsageLimitService? = nil
    ) {
        BlockActions.emergencyUnblock(
            schedules: schedules,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock ?? makeTimedUnblock(),
            scheduleService: makeSchedule(),
            usageLimitService: usageLimit
                ?? UsageLimitService(activityCenter: activity, sharedStore: store, ledger: InMemoryUsageLimitLedger(), limitShield: InMemoryDailyLimitShield())
        )
    }

    @Test func emergencyUnblockClearsEveryRestrictionOutright() {
        emergencyUnblock()

        #expect(screenTime.removeAllRestrictionsCalled)
        #expect(screenTime.disablePreventAppDeleteCalled)
    }

    @Test func emergencyUnblockDiscardsEveryTimedUnblockIncludingUnloadedOnes() throws {
        let groupID = UUID()
        let timedUnblock = makeTimedUnblock()
        store.timedUnblocks = try [
            timedUnblockRecord(id: TimedUnblockService.mainID, activityName: SharedConstants.mainTimedUnblockActivityName, endingIn: -60),
            timedUnblockRecord(
                id: groupID.uuidString,
                activityName: SharedConstants.groupTimedUnblockActivityName(for: groupID),
                endingIn: 600
            ),
        ]

        emergencyUnblock(timedUnblock: timedUnblock)

        #expect(store.timedUnblocks.isEmpty)
        let stopped = Set(activity.stopCalls.flatMap { $0 }.map(\.rawValue))
        #expect(stopped.contains(SharedConstants.mainTimedUnblockActivityName))
        #expect(stopped.contains(SharedConstants.groupTimedUnblockActivityName(for: groupID)))

        let foreground = FakeScreenTimeService()
        timedUnblock.reconcile(screenTimeService: foreground)
        #expect(foreground.applyShieldOnAllCalled == false)
        #expect(foreground.addToShieldsCalled == false)
    }

    @Test func emergencyUnblockDisablesSchedulesAndClearsTheOverride() {
        let schedule = BlockSchedule(
            name: "Work",
            selection: FamilyActivitySelection(),
            startHour: 9, startMinute: 0,
            durationMinutes: 60,
            weekdays: [2, 3, 4, 5, 6],
            shouldBlock: true,
            isTimed: true,
            isEnabled: true
        )
        store.scheduleOverrideActive = true

        emergencyUnblock(schedules: [schedule])

        #expect(schedule.isEnabled == false)
        #expect(store.scheduleOverrideActive == false)
    }

    @Test func emergencyUnblockLiftsSpentMaxDailyLimits() {
        let shield = InMemoryDailyLimitShield()
        let usageLimit = UsageLimitService(
            activityCenter: activity,
            sharedStore: store,
            ledger: InMemoryUsageLimitLedger(),
            limitShield: shield
        )
        let limit = UsageLimit(minutesPerDay: 30)
        usageLimit.registerAll([limit], config: UsageLimitConfig())
        store.recordUsageState(.reached, for: limit.id)
        usageLimit.registerAll([limit], config: UsageLimitConfig())
        #expect(shield.shieldedLimitIDs == [limit.id])

        emergencyUnblock(usageLimit: usageLimit)

        #expect(shield.shieldedLimitIDs.isEmpty)
        #expect(usageLimit.isDayOverridden())
    }

    // MARK: - validate

    @Test func validatePassesWithGlobalKey() throws {
        try BlockActions.validate(
            isAuthorized: true,
            hasCompletedOnboarding: true,
            keys: [Key(name: "global", type: .qr, rawValue: "g")]
        )
    }

    @Test func validateRequiresCompletedSetupFirst() {
        #expect(throws: BlockIntentError.setupIncomplete) {
            try BlockActions.validate(isAuthorized: false, hasCompletedOnboarding: false, keys: [])
        }
    }

    @Test func validateRequiresScreenTimeAuthorization() {
        #expect(throws: BlockIntentError.screenTimeNotAuthorized) {
            try BlockActions.validate(
                isAuthorized: false,
                hasCompletedOnboarding: true,
                keys: [Key(name: "global", type: .qr, rawValue: "g")]
            )
        }
    }

    @Test func validateRejectsGroupOnlyKeys() {
        #expect(throws: BlockIntentError.noGlobalKey) {
            try BlockActions.validate(
                isAuthorized: true,
                hasCompletedOnboarding: true,
                keys: [Key(name: "group", type: .qr, rawValue: "a", groupID: UUID())]
            )
        }
    }
}
