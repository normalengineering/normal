import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct AppBlockIntentPerformerTests {
    private let container: ModelContainer
    private let screenTime = FakeScreenTimeService()
    private let activity = FakeDeviceActivityCenter()
    private let store = FakeSharedStore()
    private let timedUnblock: TimedUnblockService
    private let performer: AppBlockIntentPerformer

    init() throws {
        container = try InMemoryModelContainer.make()
        timedUnblock = TimedUnblockService(activityCenter: activity, sharedStore: store, onExpiration: {})
        performer = AppBlockIntentPerformer(
            container: container,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            scheduleService: ScheduleService(activityCenter: activity, sharedStore: store),
            syncsExternalSurfaces: false
        )
    }

    private var context: ModelContext { container.mainContext }

    @discardableResult
    private func seed(
        onboarded: Bool = true,
        globalKey: Bool = true,
        mainDomains: [String] = ["example.com"]
    ) -> Settings {
        let settings = Settings()
        settings.hasCompletedOnboarding = onboarded
        settings.enableCustomDomains = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: mainDomains))
        if globalKey {
            context.insert(Key(name: "global", type: .qr, rawValue: "g"))
        }
        return settings
    }

    // MARK: - blockAll

    @Test func blockAllAppliesShieldAndReportsNewBlock() throws {
        seed()
        screenTime.stubBlockStatus = .none

        let outcome = try performer.blockAll()

        #expect(screenTime.applyShieldOnAllCalled)
        #expect(screenTime.applyShieldOnAllCustomDomains == ["example.com"])
        #expect(!outcome.wasAlreadyBlocked)
    }

    @Test func blockAllReportsAlreadyBlocked() throws {
        seed()
        screenTime.stubBlockStatus = .all

        let outcome = try performer.blockAll()

        #expect(outcome.wasAlreadyBlocked)
    }

    @Test func blockAllDuringTimedUnblockIsNotAlreadyBlocked() throws {
        seed()
        screenTime.stubBlockStatus = .all
        try timedUnblock.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )

        let outcome = try performer.blockAll()

        #expect(!outcome.wasAlreadyBlocked)
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func blockAllRequiresSomethingSelected() {
        seed(mainDomains: [])

        #expect(throws: BlockIntentError.noAppsSelected) {
            try performer.blockAll()
        }
        #expect(!screenTime.applyShieldOnAllCalled)
    }

    @Test func blockAllRequiresCompletedSetup() {
        seed(onboarded: false)

        #expect(throws: BlockIntentError.setupIncomplete) {
            try performer.blockAll()
        }
    }

    @Test func blockAllRequiresScreenTimeAuthorization() {
        seed()
        screenTime.stubIsAuthorizedNow = false

        #expect(throws: BlockIntentError.screenTimeNotAuthorized) {
            try performer.blockAll()
        }
        #expect(!screenTime.applyShieldOnAllCalled)
    }

    @Test func blockAllRequiresGlobalKey() {
        seed(globalKey: false)
        context.insert(Key(name: "group", type: .qr, rawValue: "a", groupID: UUID()))

        #expect(throws: BlockIntentError.noGlobalKey) {
            try performer.blockAll()
        }
    }

    // MARK: - blockGroup

    @Test func blockGroupResolvesGroupById() throws {
        seed()
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection(), customDomains: ["x.com"])
        context.insert(group)
        context.insert(AppGroup(name: "Games", selection: FamilyActivitySelection()))

        let outcome = try performer.blockGroup(id: group.id)

        #expect(outcome == BlockOutcome(name: "Social", wasAlreadyBlocked: false))
        #expect(screenTime.addToShieldsCalled)
        #expect(screenTime.addToShieldsCustomDomains == ["x.com"])
    }

    @Test func blockGroupThrowsForDeletedGroup() {
        seed()

        #expect(throws: BlockIntentError.groupNotFound) {
            try performer.blockGroup(id: UUID())
        }
        #expect(!screenTime.addToShieldsCalled)
    }

    @Test func blockGroupEndsTimedUnblock() throws {
        seed()
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection())
        context.insert(group)
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: group.id,
            selection: group.selection,
            screenTimeService: screenTime
        )
        screenTime.stubBlockStatus = .all

        let outcome = try performer.blockGroup(id: group.id)

        #expect(!outcome.wasAlreadyBlocked)
        #expect(!timedUnblock.isGroupUnblockActive(groupId: group.id))
    }

    @Test func blockGroupReportsAlreadyBlocked() throws {
        seed()
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection())
        context.insert(group)
        screenTime.stubBlockStatus = .all

        let outcome = try performer.blockGroup(id: group.id)

        #expect(outcome.wasAlreadyBlocked)
    }
}
