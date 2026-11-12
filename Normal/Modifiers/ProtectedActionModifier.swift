import SwiftUI

struct ProtectedActionModifier: ViewModifier {
    @Binding var action: (@MainActor () -> Void)?
    var allowBypass: Bool
    var defaultKeyType: KeyType?
    var requestedKeyType: KeyType?
    var keyGroupID: UUID?

    func body(content: Content) -> some View {
        content
            .screenTimeGuard(action: $action)
            .keySelect(
                action: $action,
                allowBypass: allowBypass,
                defaultKeyType: defaultKeyType,
                requestedKeyType: requestedKeyType,
                keyGroupID: keyGroupID
            )
    }
}

extension View {
    func protectedAction(
        _ action: Binding<(@MainActor () -> Void)?>,
        allowBypass: Bool = false,
        defaultKeyType: KeyType? = nil,
        requestedKeyType: KeyType? = nil,
        keyGroupID: UUID? = nil
    ) -> some View {
        modifier(ProtectedActionModifier(
            action: action,
            allowBypass: allowBypass,
            defaultKeyType: defaultKeyType,
            requestedKeyType: requestedKeyType,
            keyGroupID: keyGroupID
        ))
    }
}
