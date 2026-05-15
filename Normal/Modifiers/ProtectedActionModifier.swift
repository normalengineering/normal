import SwiftUI

struct ProtectedActionModifier: ViewModifier {
    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?

    func body(content: Content) -> some View {
        content
            .screenTimeGuard(action: $action)
            .keySelect(action: $action, allowBypass: allowBypass, defaultKeyType: defaultKeyType)
    }
}

extension View {
    func protectedAction(
        _ action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false,
        defaultKeyType: KeyType? = nil
    ) -> some View {
        modifier(ProtectedActionModifier(
            action: action,
            allowBypass: allowBypass,
            defaultKeyType: defaultKeyType
        ))
    }
}
