import SwiftData
import SwiftUI

extension View {
    func settingsToolbar() -> some View {
        modifier(SettingsToolbarModifier())
    }
}

private struct SettingsToolbarModifier: ViewModifier {
    @Environment(\.navigationCoordinator) private var navigationCoordinator
    @Query private var allSettings: [Settings]

    private var hideDonateButton: Bool {
        allSettings.first?.hideDonateButton ?? false
    }

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigationCoordinator.presentSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityIdentifier("nav.settings")
                }

                if !hideDonateButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            navigationCoordinator.presentSettings(tab: .donation)
                        } label: {
                            Label("Donate", systemImage: "heart.fill")
                        }
                        .tint(.pink)
                        .accessibilityIdentifier("nav.donate")
                    }
                }
            }
    }
}
