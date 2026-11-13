import SwiftUI

struct KeyProtectedToggle: View {
    let title: LocalizedStringKey
    let isOn: Bool
    var defaultKeyType: KeyType?
    let onEnable: @MainActor () -> Void
    let onDisable: @MainActor (KeyProof) -> Void

    @State private var authAction: ProtectedAction?

    private var binding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { isOn in
                authAction = isOn ? .tighten { onEnable() } : .weaken { proof in onDisable(proof) }
            }
        )
    }

    var body: some View {
        Toggle(title, isOn: binding)
            .protectedAction($authAction, defaultKeyType: defaultKeyType)
    }
}
