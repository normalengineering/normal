import CoreLocation
import DeviceActivity
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
    private let location: FakeLocationProvider
    private let clock = TestClock()
    private let timedUnblock: TimedUnblockService
    private let now = Date()

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
        location = FakeLocationProvider(
            outcome: .location(Self.fix(latitude: 37.3349, longitude: -122.0090, at: now)),
            authorizationStatus: .authorizedAlways
        )
    }

    private static func fix(latitude: Double, longitude: Double, at timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
    }

    private var performer: AppUnblockIntentPerformer {
        performer(deadline: .seconds(300))
    }

    private func performer(deadline: Duration) -> AppUnblockIntentPerformer {
        let now = now
        return AppUnblockIntentPerformer(
            container: container,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            unlockInbox: inbox,
            locationVerifier: BackgroundLocationVerifier(
                provider: location,
                deadline: deadline,
                pollInterval: .milliseconds(1),
                now: { now }
            ),
            syncsExternalSurfaces: false
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

    @Test func blockedAppsContinueInApp() async throws {
        try seed()
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(request()) == .continueInApp(.checkKey))
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func nothingBlockedIsAlreadyUnblocked() async throws {
        try seed()
        screenTime.stubBlockStatus = .none

        #expect(try await performer.unblock(request()) == .alreadyUnblocked(name: "All Apps"))
    }

    @Test func activeMainUnblockReportsTheRunningTimer() async throws {
        try seed()
        try timedUnblock.startMain(duration: .fifteenMinutes, selection: FamilyActivitySelection(), screenTimeService: screenTime)
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(request()) == .timedUnblockRunning(name: "All Apps"))
    }

    @Test func activeGroupUnblockReportsTheRunningTimer() async throws {
        try seed()
        let group = try seedGroup()
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: group.id,
            selection: group.selection,
            screenTimeService: screenTime
        )
        screenTime.stubBlockStatus = .some

        #expect(try await performer.unblock(request(group: group.id)) == .timedUnblockRunning(name: "Social"))
    }

    @Test func expiredTimedUnblockIsNotMistakenForActive() async throws {
        try seed()
        try timedUnblock.startMain(duration: .fifteenMinutes, selection: FamilyActivitySelection(), screenTimeService: screenTime)
        clock.now = clock.now.addingTimeInterval(20 * 60)
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(request()) == .continueInApp(.checkKey))
    }

    @Test func doesNotRequireAGlobalKey() async throws {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        settings.enableCustomDomains = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: ["example.com"]))
        try context.save()
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(request()) == .continueInApp(.checkKey))
    }

    @Test func requiresCompletedSetup() async throws {
        try seed(onboarded: false)

        await #expect(throws: BlockIntentError.setupIncomplete) {
            try await performer.unblock(request())
        }
    }

    @Test func requiresScreenTimeAuthorization() async throws {
        try seed()
        screenTime.stubIsAuthorizedNow = false

        await #expect(throws: BlockIntentError.screenTimeNotAuthorized) {
            try await performer.unblock(request())
        }
    }

    @Test func requiresSomethingSelected() async throws {
        try seed(mainDomains: [])

        await #expect(throws: BlockIntentError.noAppsSelected) {
            try await performer.unblock(request())
        }
    }

    @Test func throwsForDeletedGroup() async throws {
        try seed()

        await #expect(throws: BlockIntentError.groupNotFound) {
            try await performer.unblock(request(group: UUID()))
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

    // MARK: - Location

    private func locationRequest(group: UUID? = nil, duration: UnlockDurationRequest = .fixed(.oneHour)) -> UnblockRequest {
        UnblockRequest(groupID: group, duration: duration, keyType: .location)
    }

    @Test func locationKeyUnblocksWithoutOpeningNormal() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest()) == .unblocked(name: "All Apps", length: .timed(.oneHour)))
        #expect(timedUnblock.isMainUnblockActive)
    }

    @Test func locationKeyUsesTheDefaultDuration() async throws {
        let settings = try seed()
        context.insert(locationKey())
        settings.defaultDuration = .thirtyMinutes
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest(duration: .useDefault)) == .unblocked(name: "All Apps", length: .timed(.thirtyMinutes)))
    }

    @Test func locationKeyUnblocksUntilManuallyReBlocked() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest(duration: .permanent)) == .unblocked(name: "All Apps", length: .permanent))
        #expect(screenTime.unblockAllCalled)
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func onlyLocationKeyIsUsedWithoutAKeyType() async throws {
        let settings = Settings()
        settings.hasCompletedOnboarding = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: ["example.com"]))
        settings.enableCustomDomains = true
        context.insert(locationKey())
        try context.save()
        screenTime.stubBlockStatus = .all

        let result = try await performer.unblock(UnblockRequest(groupID: nil, duration: .fixed(.oneHour), keyType: nil))

        #expect(result == .unblocked(name: "All Apps", length: .timed(.oneHour)))
    }

    @Test func choosingTheDurationInNormalHandsOff() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest(duration: .ask)) == .continueInApp(.checkKey))
        #expect(location.requestCount == 0)
    }

    @Test func outsideTheZoneThrows() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        location.outcome = .location(Self.fix(latitude: 51.5074, longitude: -0.1278, at: now))

        await #expect(throws: UnblockIntentError.notAtLocation(.unblock)) {
            try await performer.unblock(locationRequest())
        }
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func whileUsingOnlyHandsOffWithAReason() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        location.authorizationStatus = .authorizedWhenInUse

        #expect(try await performer.unblock(locationRequest()) == .continueInApp(.backgroundLocationOff))
    }

    @Test func preciseLocationOffHandsOffWithAReason() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        location.accuracyAuthorization = .reducedAccuracy

        #expect(try await performer.unblock(locationRequest()) == .continueInApp(.preciseLocationOff))
    }

    @Test func noFixHandsOffWithAReason() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        location.outcome = .throwGeneric

        #expect(try await performer(deadline: .milliseconds(150)).unblock(locationRequest()) == .continueInApp(.noLocationFix))
    }

    @Test(.timeLimit(.minutes(5))) func timerStartedDuringTheCheckIsNotReplaced() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        location.outcome = .pending
        let performer = performer
        let task = Task { try await performer.unblock(locationRequest(duration: .permanent)) }
        await location.waitForRequests(1)

        try timedUnblock.startMain(duration: .fifteenMinutes, selection: FamilyActivitySelection(), screenTimeService: screenTime)
        location.deliverPending(Self.fix(latitude: 37.3349, longitude: -122.0090, at: now))

        #expect(try await task.value == .timedUnblockRunning(name: "All Apps"))
        #expect(!screenTime.unblockAllCalled)
    }

    @Test(.timeLimit(.minutes(5))) func groupDeletedDuringTheCheckIsNotUnblocked() async throws {
        try seed()
        let group = try seedGroup()
        context.insert(locationKey(groupID: group.id))
        screenTime.stubBlockStatus = .all
        location.outcome = .pending
        let performer = performer
        let task = Task { try await performer.unblock(locationRequest(group: group.id)) }
        await location.waitForRequests(1)

        context.delete(group)
        try context.save()
        location.deliverPending(Self.fix(latitude: 37.3349, longitude: -122.0090, at: now))

        await #expect(throws: BlockIntentError.groupNotFound) {
            try await task.value
        }
    }

    @Test func unblockAllIgnoresGroupLocationKeys() async throws {
        try seed()
        let group = try seedGroup()
        context.insert(locationKey(groupID: group.id))
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest()) == .continueInApp(.checkKey))
        #expect(location.requestCount == 0)
    }

    @Test func unblockGroupAcceptsItsOwnLocationKey() async throws {
        try seed()
        let group = try seedGroup()
        context.insert(locationKey(groupID: group.id))
        screenTime.stubBlockStatus = .all

        #expect(try await performer.unblock(locationRequest(group: group.id)) == .unblocked(name: "Social", length: .timed(.oneHour)))
        #expect(timedUnblock.isGroupUnblockActive(groupId: group.id))
    }

    @Test func failingToStartTheUnblockThrows() async throws {
        try seed()
        context.insert(locationKey())
        screenTime.stubBlockStatus = .all
        activity.startError = DeviceActivityCenter.MonitoringError.excessiveActivities

        await #expect(throws: UnblockIntentError.unblockFailed) {
            try await performer.unblock(locationRequest())
        }
        #expect(!timedUnblock.isMainUnblockActive)
    }
}
