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
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "ScreenTime")

    private static let authorizedKey = "hasAuthorizedFamilyControls"

    init(defaults: UserDefaults = .standard, shield: ShieldStoring? = nil) {
        self.defaults = defaults
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

    func applyShieldOnAll(selection: FamilyActivitySelection, blockAllPreventsAppDelete: Bool) {
        shield.replace(with: selection)
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
        notifyUpdate()
    }

    func addToShields(selection: FamilyActivitySelection) {
        shield.union(with: selection)
        notifyUpdate()
    }

    func removeFromShields(selection: FamilyActivitySelection) {
        shield.subtract(with: selection)
        notifyUpdate()
    }

    func activeShieldCount() -> Int {
        _ = lastUpdate
        return shield.shieldedCount()
    }

    func blockStatus(selection: FamilyActivitySelection?) -> BlockStatus {
        _ = lastUpdate
        return shield.status(for: selection)
    }

    func isShielded(_ token: SelectedTokenKind) -> Bool {
        _ = lastUpdate
        return shield.isShielded(token)
    }
}
