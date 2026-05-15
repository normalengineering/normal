import SwiftUI

struct AppDeleteToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @State private var authAction: (@MainActor () -> Void)?
    @State private var pendingValue: Bool?

    private var binding: Binding<Bool> {
        Binding(
            get: { screenTimeService.isAppDeleteDisabled },
            set: { newValue in
                pendingValue = newValue
                authAction = {
                    newValue
                        ? screenTimeService.enablePreventAppDelete()
                        : screenTimeService.disablePreventAppDelete()
                }
            }
        )
    }

    var body: some View {
        Section(
            footer: Text("When enabled, apps cannot be uninstalled from this device.")
        ) {
            Toggle("Prevent App Deletion", isOn: binding)
                .tint(.accentColor)
        }
        .protectedAction($authAction, allowBypass: pendingValue == true)
    }
}
