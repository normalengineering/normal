import SwiftUI

@MainActor
@Observable
final class NavigationCoordinator {
    var isSettingsPresented = false
    private(set) var settingsInitialTab: SettingsTab = .general

    func presentSettings(tab: SettingsTab = .general) {
        settingsInitialTab = tab
        isSettingsPresented = true
    }

    func dismissSettings() { isSettingsPresented = false }
}

extension EnvironmentValues {
    @Entry var navigationCoordinator: NavigationCoordinator = .init()
}
