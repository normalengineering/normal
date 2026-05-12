import SwiftUI

struct AppDeleteToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @State private var authAction: (@MainActor () -> Void)?
    @State private var pendingValue: Bool?

    private var appDeleteBinding: Binding<Bool> {
        Binding(
            get: { screenTimeService.isAppDeleteDisabled },
            set: { newValue in
                pendingValue = newValue
                authAction = {
                    if newValue {
                        screenTimeService.enablePreventAppDelete()
                    } else {
                        screenTimeService.disablePreventAppDelete()
                    }
                }
            }
        )
    }

    var body: some View {
        Section(
            footer: Text("When enabled, apps cannot be uninstalled from this device.")
        ) {
            Toggle("Prevent App Deletion", isOn: appDeleteBinding)
                .tint(.accentColor)
        }
        .screenTimeGuard(action: $authAction)
        .keySelect(action: $authAction, allowBypass: pendingValue == true)
    }
}
