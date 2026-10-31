import SwiftUI

struct HideBlockedAppsToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    var body: some View {
        Section {
            Toggle(
                "Hide Blocked Apps",
                isOn: Binding(
                    get: { screenTimeService.isHidingBlockedApps },
                    set: { screenTimeService.setHidingBlockedApps($0) }
                )
            )
            .tint(.accentColor)
            .accessibilityIdentifier("settings.hideBlockedAppsToggle")
        } header: {
            Text("Hidden Apps")
        } footer: {
            Text("Individually selected apps are removed from the Home Screen, App Library and Search while blocked. Apps blocked through a category or a daily limit stay blocked but remain visible. When unblocked, apps may reappear in the App Library rather than their original Home Screen spot.")
        }
    }
}
