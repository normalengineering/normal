import SwiftUI

struct KeyProtectedToggle: View {
    let title: LocalizedStringKey
    let isOn: Bool
    var defaultKeyType: KeyType?
    let onChange: @MainActor (Bool) -> Void

    @State private var authAction: (@MainActor () -> Void)?
    @State private var pendingValue: Bool?

    private var binding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                pendingValue = newValue
                authAction = { onChange(newValue) }
            }
        )
    }

    var body: some View {
        Toggle(title, isOn: binding)
            .protectedAction($authAction, allowBypass: pendingValue == true, defaultKeyType: defaultKeyType)
    }
}
