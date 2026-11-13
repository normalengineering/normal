import SwiftUI

struct AppDeleteToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    var body: some View {
        Section(
            footer: Text("When enabled, apps cannot be uninstalled from this device.")
        ) {
            KeyProtectedToggle(
                title: "Prevent App Deletion",
                isOn: screenTimeService.isAppDeleteDisabled,
                onEnable: { screenTimeService.enablePreventAppDelete() },
                onDisable: { screenTimeService.disablePreventAppDelete($0) }
            )
            .accessibilityIdentifier("home.preventDeleteToggle")
        }
    }
}
