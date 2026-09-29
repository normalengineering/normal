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
