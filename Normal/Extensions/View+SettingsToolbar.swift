import SwiftUI

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}

private struct SettingsToolbarModifier: ViewModifier {
    @Environment(\.navigationCoordinator) private var navigationCoordinator

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigationCoordinator.presentSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
    }
}
