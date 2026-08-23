import FamilyControls
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ScreenTimeService: ScreenTimeProviding {
    var authorizationState: AuthorizationState = .notAuthorized
    var lastUpdate: Date = .now

    private let shield: ShieldStoring
    private let authCenter = AuthorizationCenter.shared
    private let defaults: UserDefaults
    private let sharedStore: any SharedStoreProviding
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "ScreenTime")

    private static let authorizedKey = "hasAuthorizedFamilyControls"

    init(
        defaults: UserDefaults = .standard,
        shield: ShieldStoring? = nil,
        sharedStore: any SharedStoreProviding = SharedStore()
    ) {
        self.defaults = defaults
        self.sharedStore = sharedStore
        self.shield = shield
            ?? (UITestSupport.isActive ? InMemoryShieldStore() : ManagedSettingsShieldStore())
        Task { await checkAuthorizationStatus() }
    }

    var isAppDeleteDisabled: Bool {
        _ = lastUpdate
        return shield.denyAppRemoval
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
        if authorizationState == .authorized { return true }
        await requestAuthorization()
        return authorizationState == .authorized
    }

    func enablePreventAppDelete() {
        shield.denyAppRemoval = true
        notifyUpdate()
    }

    func disablePreventAppDelete() {
        shield.denyAppRemoval = false
        notifyUpdate()
    }

    func applyShieldOnAll(
        selection: FamilyActivitySelection,
        customDomains: [String] = [],
        blockAllPreventsAppDelete: Bool
    ) {
        shield.replace(with: selection, customDomains: customDomains)
        if blockAllPreventsAppDelete {
            shield.denyAppRemoval = true
        }
        notifyUpdate()
    }

    func removeShieldOnAll(blockAllPreventsAppDelete: Bool) {
        shield.clear()
        if blockAllPreventsAppDelete {
            shield.denyAppRemoval = false
        }
        reapplyUsageFloor(blockAllPreventsAppDelete: blockAllPreventsAppDelete)
        notifyUpdate()
    }

    func addToShields(selection: FamilyActivitySelection, customDomains: [String] = []) {
        shield.union(with: selection, customDomains: customDomains)
        notifyUpdate()
    }

    func removeFromShields(selection: FamilyActivitySelection, customDomains: [String] = []) {
        shield.subtract(with: selection, customDomains: customDomains)
        reapplyUsageFloor()
        notifyUpdate()
    }

    /// Shields never drop below the limits that have already run out today.
    ///
    /// Enforced here rather than at each unblock call site, so every unblock
    /// reachable from the app — Home, groups, the widget — honours a spent
    /// allowance. Scheduled windows fire inside `NormalMonitor` instead and
    /// apply the same floor there.
    private func reapplyUsageFloor(blockAllPreventsAppDelete: Bool = false) {
        var restored = false
        for limit in sharedStore.reachedUsageLimits() {
            guard let selection = try? FamilyActivitySelection.fromData(limit.selectionData) else { continue }
            shield.union(with: selection, customDomains: [])
            restored = true
            // Re-shielding without this leaves the app deletable while blocks
            // are in force — the exact hole the setting exists to close.
            if blockAllPreventsAppDelete {
                shield.denyAppRemoval = true
            }
        }
        if restored { notifyUpdate() }
    }

    func clearCustomDomainFilter() {
        shield.clearCustomDomainFilter()
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
}
