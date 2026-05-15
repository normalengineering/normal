import SwiftUI

@MainActor
@Observable
final class NavigationCoordinator {
    var isSettingsPresented = false

    func presentSettings() { isSettingsPresented = true }
    func dismissSettings() { isSettingsPresented = false }
}

extension EnvironmentValues {
    @Entry var navigationCoordinator: NavigationCoordinator = .init()
}
