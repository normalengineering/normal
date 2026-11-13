import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct AppUnblockIntentPerformerTests {
    private let container: ModelContainer
    private let screenTime = FakeScreenTimeService()
    private let activity = FakeDeviceActivityCenter()
    private let store = FakeSharedStore()
    private let inbox = UnlockRequestInbox()
    private let clock = TestClock()
    private let timedUnblock: TimedUnblockService
    private let performer: AppUnblockIntentPerformer

    private final class TestClock {
        var now = Date()
    }

    init() throws {
        container = try InMemoryModelContainer.make()
        let clock = clock
        timedUnblock = TimedUnblockService(
            activityCenter: activity,
            sharedStore: store,
            clock: { clock.now },
            onExpiration: {}
        )
        performer = AppUnblockIntentPerformer(
            container: container,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            unlockInbox: inbox
        )
    }

    private var context: ModelContext {
        container.mainContext
    }

    @discardableResult
    private func seed(onboarded: Bool = true, mainDomains: [String] = ["example.com"]) throws -> Settings {
        let settings = Settings()
        settings.hasCompletedOnboarding = onboarded
        settings.enableCustomDomains = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: mainDomains))
        context.insert(Key(name: "global", type: .qr, rawValue: "g"))
        try context.save()
        return settings
    }

    private func seedGroup() throws -> AppGroup {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection())
        context.insert(group)
        try context.save()
        return group
    }

    private func locationKey(groupID: UUID? = nil) -> Key {
        Key(name: "Place", latitude: 37.3349, longitude: -122.0090, radiusMeters: 200, radiusKind: .unblock, groupID: groupID)
    }

    private func request(group: UUID? = nil, key: KeyType? = .nfc) -> UnblockRequest {
        UnblockRequest(groupID: group, duration: .fixed(.oneHour), keyType: key)
    }

    @Test func blockedAppsContinueInApp() throws {
        try seed()
        screenTime.stubBlockStatus = .all

        #expect(try performer.unblock(request()) == .continueInApp)
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func nothingBlockedIsAlreadyUnblocked() throws {
        try seed()
        screenTime.stubBlockStatus = .none

        #expect(try performer.unblock(request()) == .alreadyUnblocked(name: "All Apps"))
    }

    @Test func activeMainUnblockReportsTheRunningTimer() throws {
        try seed()
        try timedUnblock.startMain(duration: .fifteenMinutes, selection: FamilyActivitySelection(), screenTimeService: screenTime)
        screenTime.stubBlockStatus = .all

        #expect(try performer.unblock(request()) == .timedUnblockRunning(name: "All Apps"))
    }

    @Test func activeGroupUnblockReportsTheRunningTimer() throws {
        try seed()
        let group = try seedGroup()
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: group.id,
            selection: group.selection,
            screenTimeService: screenTime
        )
        screenTime.stubBlockStatus = .some

        #expect(try performer.unblock(request(group: group.id)) == .timedUnblockRunning(name: "Social"))
    }

    @Test func expiredTimedUnblockIsNotMistakenForActive() throws {
        try seed()
        try timedUnblock.startMain(duration: .fifteenMinutes, selection: FamilyActivitySelection(), screenTimeService: screenTime)
        clock.now = clock.now.addingTimeInterval(20 * 60)
        screenTime.stubBlockStatus = .all

        #expect(try performer.unblock(request()) == .continueInApp)
    }

    @Test func doesNotRequireAGlobalKey() throws {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        settings.enableCustomDomains = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: ["example.com"]))
        try context.save()
        screenTime.stubBlockStatus = .all

        #expect(try performer.unblock(request()) == .continueInApp)
    }

    @Test func requiresCompletedSetup() throws {
        try seed(onboarded: false)

        #expect(throws: BlockIntentError.setupIncomplete) {
            try performer.unblock(request())
        }
    }

    @Test func requiresScreenTimeAuthorization() throws {
        try seed()
        screenTime.stubIsAuthorizedNow = false

        #expect(throws: BlockIntentError.screenTimeNotAuthorized) {
            try performer.unblock(request())
        }
    }

    @Test func requiresSomethingSelected() throws {
        try seed(mainDomains: [])

        #expect(throws: BlockIntentError.noAppsSelected) {
            try performer.unblock(request())
        }
    }

    @Test func throwsForDeletedGroup() throws {
        try seed()

        #expect(throws: BlockIntentError.groupNotFound) {
            try performer.unblock(request(group: UUID()))
        }
    }

    @Test func continueInAppPostsTheRequest() throws {
        try seed()
        let groupID = UUID()

        performer.continueInApp(request(group: groupID, key: .nfc))

        #expect(inbox.pending == UnblockRequest(groupID: groupID, duration: .fixed(.oneHour), keyType: .nfc))
    }

    @Test func continueInAppUsesTheDefaultKey() throws {
        let settings = try seed()
        context.insert(locationKey())
        settings.defaultKeyType = .location

        performer.continueInApp(request(key: nil))

        #expect(inbox.pending?.keyType == .location)
    }

    @Test func continueInAppUsesTheOnlyKeyType() throws {
        try seed()

        performer.continueInApp(request(key: nil))

        #expect(inbox.pending?.keyType == .qr)
    }

    @Test func continueInAppIgnoresKeysFromOtherGroups() throws {
        try seed()
        context.insert(locationKey(groupID: UUID()))

        performer.continueInApp(request(key: nil))

        #expect(inbox.pending?.keyType == .qr)
    }
}
