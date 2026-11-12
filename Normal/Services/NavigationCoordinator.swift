import SwiftUI

enum PendingAction: Equatable {
    case unblock(UnblockRequest)
    case blockGroup(UUID)
}

struct ActionRequest: Equatable {
    let token: UUID
    let action: PendingAction
}

@MainActor
@Observable
final class NavigationCoordinator {
    var isSettingsPresented = false
    private(set) var settingsInitialTab: SettingsTab = .general

    private(set) var pendingAction: ActionRequest?
    private var actionAfterSettings: ActionRequest?

    func presentSettings(tab: SettingsTab = .general) {
        settingsInitialTab = tab
        isSettingsPresented = true
    }

    func dismissSettings() {
        isSettingsPresented = false
    }

    func settingsDidDismiss() {
        guard let actionAfterSettings else { return }
        self.actionAfterSettings = nil
        pendingAction = actionAfterSettings
    }

    func requestUnblock(_ request: UnblockRequest) {
        post(.unblock(request))
    }

    func requestGroupBlock(groupID: UUID) {
        post(.blockGroup(groupID))
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
            requestUnblock(UnblockRequest(groupID: groupID, duration: duration, keyType: keyType))
        case WidgetDeepLink.blockHost:
            requestGroupBlock(groupID: groupID)
        default:
            return
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }

    private func post(_ action: PendingAction) {
        let request = ActionRequest(token: UUID(), action: action)
        if isSettingsPresented {
            actionAfterSettings = request
            isSettingsPresented = false
        } else {
            pendingAction = request
        }
    }
}

extension NavigationCoordinator {
    static let fallback = NavigationCoordinator()
}

extension EnvironmentValues {
    @Entry var navigationCoordinator: NavigationCoordinator = .fallback
}
