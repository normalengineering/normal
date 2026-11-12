import SwiftUI

enum PendingAction: Equatable {
    case unlock(duration: UnlockDurationRequest, keyType: KeyType?)
    case block
}

struct ActionRequest: Equatable {
    let token: UUID
    let groupID: UUID?
    let action: PendingAction
}

@MainActor
@Observable
final class NavigationCoordinator {
    var isSettingsPresented = false
    private(set) var settingsInitialTab: SettingsTab = .general

    var pendingAction: ActionRequest?

    func presentSettings(tab: SettingsTab = .general) {
        settingsInitialTab = tab
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func requestUnlock(groupID: UUID?, duration: UnlockDurationRequest, keyType: KeyType?) {
        pendingAction = ActionRequest(
            token: UUID(),
            groupID: groupID,
            action: .unlock(duration: duration, keyType: keyType)
        )
    }

    func requestGroupBlock(groupID: UUID) {
        pendingAction = ActionRequest(token: UUID(), groupID: groupID, action: .block)
    }

    func handle(url: URL) {
        guard url.scheme == WidgetDeepLink.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        let items = components.queryItems ?? []
        guard let groupValue = items.first(where: { $0.name == WidgetDeepLink.groupQueryItem })?.value,
              let groupID = UUID(uuidString: groupValue)
        else { return }

        switch url.host {
        case WidgetDeepLink.unlockHost:
            let duration = UnlockDurationRequest(
                queryValue: items.first { $0.name == WidgetDeepLink.durationQueryItem }?.value
            )
            let keyType = items.first { $0.name == WidgetDeepLink.keyQueryItem }?.value
                .flatMap { KeyType(rawValue: $0) }
            requestUnlock(groupID: groupID, duration: duration, keyType: keyType)
        case WidgetDeepLink.blockHost:
            requestGroupBlock(groupID: groupID)
        default:
            return
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}

extension NavigationCoordinator {
    static let fallback = NavigationCoordinator()
}

extension EnvironmentValues {
    @Entry var navigationCoordinator: NavigationCoordinator = .fallback
}
