import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum AuthorizationState {
    case authorized
    case notAuthorized
}

@Observable
class ScreenTimeService {
    @MainActor static let shared = ScreenTimeService()

    var authorizationState: AuthorizationState = .notAuthorized

    private let store = ManagedSettingsStore()
    private let authCenter = AuthorizationCenter.shared
    private let authorizedKey = "hasAuthorizedFamilyControls"

    init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    @MainActor
    func checkAuthorizationStatus() async {
        let status = authCenter.authorizationStatus

        if status == .approved {
            authorizationState = .authorized
        } else if UserDefaults.standard.bool(forKey: authorizedKey) {
            await requestAuthorization()
        } else {
            authorizationState = .notAuthorized
        }
    }

    @MainActor
    func requestAuthorization() async {
        do {
            try await authCenter.requestAuthorization(for: .individual)
            authorizationState = .authorized
            UserDefaults.standard.set(true, forKey: authorizedKey)
        } catch {
            print("Failed to authorize: \(error.localizedDescription)")
        }
    }

    @MainActor
    func block(appGroup: AppGroup) {
        let applications = appGroup.selection.applicationTokens
        let categories = appGroup.selection.categoryTokens
        let webDomains = appGroup.selection.webDomainTokens

        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : ShieldSettings.ActivityCategoryPolicy.specific(
            categories,
            except: Set()
        )
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    }
}
