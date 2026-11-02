import SwiftUI

struct HideBlockedAppsToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    var body: some View {
        Toggle(
            "Hide Blocked Apps",
            isOn: Binding(
                get: { screenTimeService.isHidingBlockedApps },
                set: { screenTimeService.setHidingBlockedApps($0) }
            )
        )
        .tint(.accentColor)
        .accessibilityIdentifier("settings.hideBlockedAppsToggle")
    }
}
