import SwiftUI

enum GroupAction: Equatable {
    case unlock(duration: UnblockDuration?, keyType: KeyType?)
    case block
}

struct GroupActionRequest: Equatable {
    let token: UUID
    let groupID: UUID
    let action: GroupAction
}

@MainActor
@Observable
final class NavigationCoordinator {
    var isSettingsPresented = false
    private(set) var settingsInitialTab: SettingsTab = .general

    var pendingGroupAction: GroupActionRequest?

    func presentSettings(tab: SettingsTab = .general) {
        settingsInitialTab = tab
        isSettingsPresented = true
    }

    func dismissSettings() { isSettingsPresented = false }

    func requestGroupUnlock(groupID: UUID, duration: UnblockDuration?, keyType: KeyType?) {
        pendingGroupAction = GroupActionRequest(
            token: UUID(),
            groupID: groupID,
            action: .unlock(duration: duration, keyType: keyType)
        )
    }

    func requestGroupBlock(groupID: UUID) {
        pendingGroupAction = GroupActionRequest(token: UUID(), groupID: groupID, action: .block)
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
            let duration = items.first { $0.name == WidgetDeepLink.durationQueryItem }?.value
                .flatMap { Int($0) }
                .flatMap { UnblockDuration(rawValue: $0) }
            let keyType = items.first { $0.name == WidgetDeepLink.keyQueryItem }?.value
                .flatMap { KeyType(rawValue: $0) }
            requestGroupUnlock(groupID: groupID, duration: duration, keyType: keyType)
        case WidgetDeepLink.blockHost:
            requestGroupBlock(groupID: groupID)
        default:
            return
        }
    }

    func clearPendingGroupAction() { pendingGroupAction = nil }
}

extension EnvironmentValues {
    @Entry var navigationCoordinator: NavigationCoordinator = .init()
}
