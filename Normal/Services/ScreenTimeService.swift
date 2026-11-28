import DeviceActivity
import FamilyControls
import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class ScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    private let shield: ShieldStoring
    private let sharedStore: any SharedStoreProviding
    private let activityCenter: any DeviceActivityProviding
    private let clock: () -> Date
    private let authCenter = AuthorizationCenter.shared
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "ScreenTime")

    private static let authorizedKey = "hasAuthorizedFamilyControls"

    init(
        defaults: UserDefaults = .standard,
        shield: ShieldStoring? = nil,
        sharedStore: any SharedStoreProviding = SharedStore(),
        activityCenter: any DeviceActivityProviding = DeviceActivityCenter(),
        clock: @escaping () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.shield =
            shield
            ?? (UITestSupport.isActive ? InMemoryShieldStore() : ManagedSettingsShieldStore())
        self.sharedStore = sharedStore
        self.activityCenter = activityCenter
        self.clock = clock
    }

    var isAuthorizedNow: Bool {
        UITestSupport.isActive || authCenter.authorizationStatus == .approved
    }

    var isAppDeleteDisabled: Bool {
        _ = lastUpdate
        return shield.denyAppRemoval
    }

    var isAdultContentBlocked: Bool {
        _ = lastUpdate
        return shield.currentShields().blocksAdultContent
    }

    var isHidingBlockedApps: Bool {
        _ = lastUpdate
        return sharedStore.isHideBlockedAppsEnabled()
    }

    func notifyUpdate() {
        lastUpdate = .now
    }

    func checkAuthorizationStatus() async {
        if UITestSupport.isActive {
            authorizationState = .authorized
            return
        }
        if authCenter.authorizationStatus == .approved {
            authorizationState = .authorized
        } else if defaults.bool(forKey: Self.authorizedKey) {
            await requestAuthorization()
        } else {
            authorizationState = .notAuthorized
        }
    }

    func requestAuthorization() async {
        if UITestSupport.isActive {
            authorizationState = .authorized
            return
        }
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationState = .authorized
            defaults.set(true, forKey: Self.authorizedKey)
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func ensureAuthorized() async -> Bool {
        if authorizationState == .authorized {
            return true
        }
        await requestAuthorization()
        return authorizationState == .authorized
    }

    func enablePreventAppDelete() {
        reconcile { $0.setAppDeletionBlocked(true, at: clock()) }
    }

    func disablePreventAppDelete(_ proof: KeyProof) {
        guard proof.coversAllApps else { return }
        reconcile { $0.setAppDeletionBlocked(false, at: clock()) }
    }

    func blockAll(
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        blockAllPreventsAppDelete: Bool
    ) {
        reconcile { state in
            let now = clock()
            state.blockAll(selection, customDomains: customDomains, at: now)
            if blockAllPreventsAppDelete {
                state.setAppDeletionBlocked(true, at: now)
            }
        }
    }

    func unblockAll(blockAllPreventsAppDelete: Bool) {
        reconcile { state in
            let now = clock()
            state.unblockAll(at: now)
            if blockAllPreventsAppDelete {
                state.setAppDeletionBlocked(false, at: now)
            }
        }
    }

    func block(selection: FamilyActivitySelection, customDomains: [String] = []) {
        reconcile { $0.block(selection, customDomains: customDomains, at: clock()) }
    }

    func unblock(selection: FamilyActivitySelection, customDomains: [String] = []) {
        reconcile { $0.unblock(selection, customDomains: customDomains, at: clock()) }
    }

    func updateMainList(
        from old: FamilyActivitySelection,
        customDomains oldDomains: [String],
        to new: FamilyActivitySelection,
        customDomains newDomains: [String],
        addedBlockedAsOf addedDate: Date
    ) {
        let oldNormalized = Set(oldDomains.compactMap(DomainNormalizer.normalize))
        let newNormalized = Set(newDomains.compactMap(DomainNormalizer.normalize))
        reconcile { state in
            state.unblock(
                old.subtracting(new),
                customDomains: Array(oldNormalized.subtracting(newNormalized)),
                at: clock()
            )
            state.block(
                new.subtracting(old),
                customDomains: Array(newNormalized.subtracting(oldNormalized)),
                at: addedDate
            )
        }
    }

    func unblockRemovedFromMain(
        from old: FamilyActivitySelection,
        customDomains oldDomains: [String],
        to new: FamilyActivitySelection,
        customDomains newDomains: [String],
        clearAppDeletion: Bool
    ) {
        let oldNormalized = Set(oldDomains.compactMap(DomainNormalizer.normalize))
        let newNormalized = Set(newDomains.compactMap(DomainNormalizer.normalize))
        let removedSelection = old.subtracting(new)
        let removedDomains = Array(oldNormalized.subtracting(newNormalized))
        guard !removedSelection.isEmpty || !removedDomains.isEmpty || clearAppDeletion else { return }
        reconcile { state in
            let now = clock()
            state.unblock(removedSelection, customDomains: removedDomains, at: now)
            if clearAppDeletion {
                state.setAppDeletionBlocked(false, at: now)
            }
        }
    }

    func clearCustomDomains() {
        reconcile { state in
            state.customDomains.reset(blocking: [], at: clock())
        }
    }

    func preservePermanentSchedule(_ previous: ScheduleDTO) {
        reconcile { state in
            ShieldResolver.materializePermanentSchedule(previous, into: &state, at: clock())
        }
    }

    func removeAllRestrictions() {
        reconcile { state in
            let now = clock()
            state.unblockAll(at: now)
            state.setAppDeletionBlocked(false, at: now)
        }
        sharedStore.setAdultContentEnabled(false)
        shield.clearAllSettings()
        notifyUpdate()
    }

    func blockAdultContent() {
        setAdultContentEnabled(true)
    }

    func allowAdultContent(_ proof: KeyProof) {
        guard proof.coversAllApps else { return }
        setAdultContentEnabled(false)
    }

    private func setAdultContentEnabled(_ enabled: Bool) {
        sharedStore.setAdultContentEnabled(enabled)
        reconcile()
    }

    func setHidingBlockedApps(_ hidden: Bool) {
        sharedStore.setHideBlockedAppsEnabled(hidden)
        reconcile()
    }

    func startFresh() {
        reconcile { state in
            state = ManualBlockState()
            state.setAppDeletionBlocked(false, at: clock())
        }
    }

    func reconcile() {
        reconcile { _ in }
    }

    private func reconcile(_ update: (inout ManualBlockState) -> Void) {
        let plan = ShieldReconciler.reconcile(
            sharedStore: sharedStore,
            shields: shield,
            monitoredActivities: activityCenter.monitoredActivityNames,
            at: clock(),
            update: update
        )
        CallbackLog.record("app reconcile: \(plan.map { "\($0.applications.count) apps" } ?? "skipped, data protected")")
        notifyUpdate()
    }

    func activeShieldCount() -> Int {
        _ = lastUpdate
        return shield.shieldedCount()
    }

    func blockStatus(selection: FamilyActivitySelection?, customDomains: [String]? = nil) -> BlockStatus {
        _ = lastUpdate
        return shield.status(for: selection, customDomains: customDomains)
    }

    func isShielded(_ token: SelectedTokenKind) -> Bool {
        _ = lastUpdate
        return shield.isShielded(token)
    }

    func isCustomDomainShielded(_ domain: String) -> Bool {
        _ = lastUpdate
        return shield.isCustomDomainShielded(domain)
    }

    func hasActiveCustomDomainFilter() -> Bool {
        _ = lastUpdate
        return shield.hasActiveCustomDomainFilter()
    }
}
