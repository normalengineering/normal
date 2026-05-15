@testable import Normal
import Testing

@MainActor
struct NavigationCoordinatorTests {
    @Test func startsDismissed() {
        let c = NavigationCoordinator()
        #expect(!c.isSettingsPresented)
    }

    @Test func presentSettingsFlipsToTrue() {
        let c = NavigationCoordinator()
        c.presentSettings()
        #expect(c.isSettingsPresented)
    }

    @Test func dismissSettingsFlipsToFalse() {
        let c = NavigationCoordinator()
        c.presentSettings()
        c.dismissSettings()
        #expect(!c.isSettingsPresented)
    }
}
