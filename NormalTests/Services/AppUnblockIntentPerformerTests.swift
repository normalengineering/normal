import CoreLocation
import FamilyControls
import Foundation
@testable import Normal
import SwiftData
import Testing

@MainActor
struct AppUnblockIntentPerformerTests {
    private nonisolated static let cupertino = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    private nonisolated static let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)

    private let container: ModelContainer
    private let screenTime = FakeScreenTimeService()
    private let activity = FakeDeviceActivityCenter()
    private let store = FakeSharedStore()
    private let navigation = NavigationCoordinator()
    private let location: FakeLocationProvider
    private let timedUnblock: TimedUnblockService
    private let performer: AppUnblockIntentPerformer

    init() throws {
        container = try InMemoryModelContainer.make()
        timedUnblock = TimedUnblockService(activityCenter: activity, sharedStore: store, onExpiration: {})
        location = FakeLocationProvider(
            outcome: .location(Self.fix(at: Self.cupertino)),
            authorizationStatus: .authorizedAlways
        )
        performer = AppUnblockIntentPerformer(
            container: container,
            screenTimeService: screenTime,
            timedUnblockService: timedUnblock,
            navigation: navigation,
            locationVerifier: BackgroundLocationVerifier(provider: location),
            syncsExternalSurfaces: false
        )
    }

    private var context: ModelContext {
        container.mainContext
    }

    private static func fix(at coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func locationKey(groupID: UUID? = nil) -> Key {
        Key(
            name: "Place",
            latitude: Self.cupertino.latitude,
            longitude: Self.cupertino.longitude,
            radiusMeters: 200,
            radiusKind: .unblock,
            groupID: groupID
        )
    }

    @discardableResult
    private func seed(
        onboarded: Bool = true,
        mainDomains: [String] = ["example.com"],
        globalLocationKey: Bool = true
    ) throws -> Settings {
        let settings = Settings()
        settings.hasCompletedOnboarding = onboarded
        settings.enableCustomDomains = true
        context.insert(settings)
        context.insert(SelectedApps(selection: FamilyActivitySelection(), customDomains: mainDomains))
        context.insert(Key(name: "global", type: .qr, rawValue: "g"))
        if globalLocationKey {
            context.insert(locationKey())
        }
        try context.save()
        return settings
    }

    private func seedGroup() throws -> AppGroup {
        let group = AppGroup(name: "Social", selection: FamilyActivitySelection())
        context.insert(group)
        try context.save()
        return group
    }

    private func request(
        group: UUID? = nil,
        duration: UnlockDurationRequest = .fixed(.oneHour),
        key: KeyType? = .location
    ) -> UnblockRequest {
        UnblockRequest(groupID: group, duration: duration, keyType: key)
    }

    // MARK: - Location

    @Test func unblockAllWithLocationStartsMainUnblock() async throws {
        try seed()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request())

        #expect(outcome == .unblocked(name: "All Apps", duration: .oneHour))
        #expect(timedUnblock.isMainUnblockActive)
        #expect(!activity.startCalls.isEmpty)
    }

    @Test func unblockAllUsesDefaultDuration() async throws {
        let settings = try seed()
        settings.defaultDuration = .thirtyMinutes
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request(duration: .useDefault))

        #expect(outcome == .unblocked(name: "All Apps", duration: .thirtyMinutes))
    }

    @Test func outOfRangeThrowsWithoutUnblocking() async throws {
        try seed()
        screenTime.stubBlockStatus = .all
        location.outcome = .location(Self.fix(at: Self.london))

        await #expect(throws: UnblockIntentError.notAtUnlockLocation) {
            try await performer.unblock(request())
        }
        #expect(!timedUnblock.isMainUnblockActive)
    }

    @Test func whenInUseOnlyContinuesInApp() async throws {
        try seed()
        screenTime.stubBlockStatus = .all
        location.authorizationStatus = .authorizedWhenInUse

        let outcome = try await performer.unblock(request())

        #expect(outcome == .continueInApp)
        #expect(!timedUnblock.isMainUnblockActive)
    }

    // MARK: - Hand-off

    @Test func scanKeysAndNoKeyContinueInApp() async throws {
        try seed()
        screenTime.stubBlockStatus = .all

        for key: KeyType? in [.nfc, .qr, nil] {
            let outcome = try await performer.unblock(request(key: key))
            #expect(outcome == .continueInApp)
        }
        #expect(!timedUnblock.isMainUnblockActive)
        #expect(location.requestCount == 0)
    }

    @Test func askEachTimeContinuesInApp() async throws {
        try seed()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request(duration: .ask))

        #expect(outcome == .continueInApp)
        #expect(location.requestCount == 0)
    }

    @Test func appDefaultWithoutDefaultContinuesInApp() async throws {
        try seed()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request(duration: .useDefault))

        #expect(outcome == .continueInApp)
        #expect(location.requestCount == 0)
    }

    @Test func continueInAppRequestsMainUnlock() {
        performer.continueInApp(request(duration: .ask, key: .qr))

        #expect(navigation.pendingMainUnlock?.duration == .ask)
        #expect(navigation.pendingMainUnlock?.keyType == .qr)
        #expect(navigation.pendingGroupAction == nil)
    }

    @Test func continueInAppRequestsGroupUnlock() {
        let groupID = UUID()

        performer.continueInApp(request(group: groupID, key: .nfc))

        #expect(navigation.pendingGroupAction?.groupID == groupID)
        #expect(navigation.pendingGroupAction?.action == .unlock(duration: .fixed(.oneHour), keyType: .nfc))
        #expect(navigation.pendingMainUnlock == nil)
    }

    // MARK: - Already unblocked

    @Test func nothingBlockedIsAlreadyUnblocked() async throws {
        try seed()
        screenTime.stubBlockStatus = .none

        let outcome = try await performer.unblock(request())

        #expect(outcome == .alreadyUnblocked(name: "All Apps"))
        #expect(location.requestCount == 0)
    }

    @Test func activeMainUnblockIsAlreadyUnblocked() async throws {
        try seed()
        try timedUnblock.startMain(
            duration: .fifteenMinutes,
            selection: FamilyActivitySelection(),
            screenTimeService: screenTime
        )
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request())

        #expect(outcome == .alreadyUnblocked(name: "All Apps"))
        #expect(location.requestCount == 0)
    }

    @Test func activeGroupUnblockIsAlreadyUnblocked() async throws {
        try seed()
        let group = try seedGroup()
        try timedUnblock.startGroup(
            duration: .fifteenMinutes,
            groupId: group.id,
            selection: group.selection,
            screenTimeService: screenTime
        )
        screenTime.stubBlockStatus = .some

        let outcome = try await performer.unblock(request(group: group.id))

        #expect(outcome == .alreadyUnblocked(name: "Social"))
        #expect(location.requestCount == 0)
    }

    // MARK: - Key scope

    @Test func unblockAllIgnoresGroupLocationKeys() async throws {
        try seed(globalLocationKey: false)
        let group = try seedGroup()
        context.insert(locationKey(groupID: group.id))
        try context.save()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request())

        #expect(outcome == .continueInApp)
        #expect(location.requestCount == 0)
    }

    @Test func unblockGroupAcceptsItsOwnLocationKey() async throws {
        try seed(globalLocationKey: false)
        let group = try seedGroup()
        context.insert(locationKey(groupID: group.id))
        try context.save()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request(group: group.id))

        #expect(outcome == .unblocked(name: "Social", duration: .oneHour))
        #expect(timedUnblock.isGroupUnblockActive(groupId: group.id))
    }

    @Test func unblockGroupIgnoresOtherGroupsLocationKeys() async throws {
        try seed(globalLocationKey: false)
        let group = try seedGroup()
        context.insert(locationKey(groupID: UUID()))
        try context.save()
        screenTime.stubBlockStatus = .all

        let outcome = try await performer.unblock(request(group: group.id))

        #expect(outcome == .continueInApp)
        #expect(!timedUnblock.isGroupUnblockActive(groupId: group.id))
    }

    // MARK: - Validation

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
}
