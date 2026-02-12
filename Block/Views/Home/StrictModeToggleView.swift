import SwiftData
import SwiftUI

struct StrictModeToggleView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @State private var authAction: (@MainActor () -> Void)?
    @State private var pendingValue: Bool?

    private var strictModeBinding: Binding<Bool> {
        Binding(
            get: { screenTimeService.isStrictModeEnabled },
            set: { newValue in
                pendingValue = newValue
                authAction = {
                    if newValue {
                        screenTimeService.enableStrictMode()
                    } else {
                        screenTimeService.disableStrictMode()
                    }
                }
            }
        )
    }

    var body: some View {
        Section(
            header: Text("Configuration"),
            footer: Text("Strict mode prevents app deletion.")
        ) {
            Toggle("Strict Mode", isOn: strictModeBinding)
                .tint(.accentColor)
        }
        .keySelect(action: $authAction, allowBypass: pendingValue == true)
    }
}
