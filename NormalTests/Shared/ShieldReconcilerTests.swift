import FamilyControls
import Foundation
import ManagedSettings
@testable import Normal
import Testing

struct ShieldReconcilerTests {
    private final class RecordingShields: ShieldApplying, @unchecked Sendable {
        private let lock = NSLock()
        private var plan = ShieldPlan()
        private var inFlight = 0
        private(set) var maxInFlight = 0
        private(set) var applyCount = 0
        var readDelay: TimeInterval = 0

        init(_ plan: ShieldPlan = ShieldPlan()) {
            self.plan = plan
        }

        func currentShields() -> ShieldPlan {
            lock.withLock {
                inFlight += 1
                maxInFlight = max(maxInFlight, inFlight)
            }
            if readDelay > 0 {
                Thread.sleep(forTimeInterval: readDelay)
            }
            return lock.withLock { plan }
        }

        func apply(_ plan: ShieldPlan) {
            lock.withLock {
                self.plan = plan
                applyCount += 1
                inFlight -= 1
            }
        }

        var current: ShieldPlan {
            lock.withLock { plan }
        }
    }

    private func blocking(_ apps: [UInt8]) -> ShieldPlan {
        var plan = ShieldPlan()
        plan.applications = Set(apps.map(TokenFixtures.app))
        return plan
    }

    @Test func doesNotWriteWhenNothingChanged() {
        let store = FakeSharedStore()
        let shields = RecordingShields(blocking([1]))

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])
        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])

        #expect(shields.applyCount == 0)
        #expect(shields.current.applications == [TokenFixtures.app(1)])
    }

    @Test func leavesAppDeletionAloneWhenNoDecisionWasRecorded() {
        var current = blocking([1])
        current.denyAppRemoval = nil
        let shields = RecordingShields(current)
        let store = FakeSharedStore()
        store.manualBlockState = ManualBlockState()

        let plan = ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])

        #expect(plan?.denyAppRemoval == nil)
        #expect(plan?.applications.isEmpty == true)
    }

    @Test func savesTheManualRecordOnlyWhenItChanges() {
        let store = FakeSharedStore()
        let shields = RecordingShields(blocking([1]))

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])
        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])
        #expect(store.manualBlockStateSaveCount == 1)

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: []) {
            $0.block(TokenFixtures.selection(apps: [2]), customDomains: [], at: .now)
        }
        #expect(store.manualBlockStateSaveCount == 2)
    }

    @Test func appliesUpdateBeforeComputing() {
        let store = FakeSharedStore()
        let shields = RecordingShields()

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: []) {
            $0.block(TokenFixtures.selection(apps: [4]), customDomains: [], at: .now)
        }

        #expect(shields.current.applications == [TokenFixtures.app(4)])
        #expect(store.manualBlockState?.applications.blockedTokens == [TokenFixtures.app(4)])
    }

    @Test func keepsCustomDomainsBlockedAlongsideAdultContent() {
        let store = FakeSharedStore()
        store.customDomainsEnabled = true
        store.adultContentEnabled = true
        store.manualBlockState = ManualBlockState()
        let shields = RecordingShields()

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: []) {
            $0.block(FamilyActivitySelection(), customDomains: ["reddit.com"], at: .now)
        }

        #expect(shields.current.customDomains == ["reddit.com"])
        #expect(shields.current.blocksAdultContent)
    }

    @Test func togglingAdultContentLeavesOtherShieldsAlone() {
        let store = FakeSharedStore()
        store.customDomainsEnabled = true
        var current = blocking([1])
        current.customDomains = ["reddit.com"]
        let shields = RecordingShields(current)

        store.adultContentEnabled = true
        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])
        #expect(shields.current.blocksAdultContent)
        #expect(shields.current.applications == [TokenFixtures.app(1)])
        #expect(shields.current.customDomains == ["reddit.com"])

        store.adultContentEnabled = false
        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])
        #expect(!shields.current.blocksAdultContent)
        #expect(shields.current.applications == [TokenFixtures.app(1)])
        #expect(shields.current.customDomains == ["reddit.com"])
        #expect(shields.applyCount == 2)
    }

    @Test func hiddenAppsMatchShieldedAppsWhenEnabled() {
        let store = FakeSharedStore()
        store.hideBlockedAppsEnabled = true
        let shields = RecordingShields(blocking([1, 2]))

        ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [])

        #expect(shields.current.hiddenApplications == [TokenFixtures.app(1), TokenFixtures.app(2)])
        #expect(shields.current.applications == [TokenFixtures.app(1), TokenFixtures.app(2)])
    }

    @Test func concurrentReconcilesNeverOverlap() async {
        let lockURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).lock")
        defer { try? FileManager.default.removeItem(at: lockURL) }
        let store = FakeSharedStore()
        store.manualBlockState = ManualBlockState()
        let shields = RecordingShields()
        shields.readDelay = 0.01

        await withTaskGroup(of: Void.self) { group in
            for id in UInt8(1) ... 8 {
                group.addTask {
                    ShieldReconciler.reconcile(sharedStore: store, shields: shields, monitoredActivities: [], lockURL: lockURL) {
                        $0.block(TokenFixtures.selection(apps: [id]), customDomains: [], at: .now)
                    }
                }
            }
        }

        #expect(shields.applyCount == 8)
        #expect(shields.maxInFlight == 1)
        #expect(shields.current.applications == Set((UInt8(1) ... 8).map(TokenFixtures.app)))
    }
}
