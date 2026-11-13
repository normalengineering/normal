import SwiftUI

struct ProtectedActionModifier: ViewModifier {
    @Binding var action: ProtectedAction?
    var defaultKeyType: KeyType?
    var requestedKeyType: KeyType?
    var keyGroupID: UUID?
    var requestID: UUID?

    func body(content: Content) -> some View {
        content
            .screenTimeGuard(action: $action)
            .keySelect(
                action: $action,
                defaultKeyType: defaultKeyType,
                requestedKeyType: requestedKeyType,
                keyGroupID: keyGroupID,
                requestID: requestID
            )
    }
}

extension View {
    func protectedAction(
        _ action: Binding<ProtectedAction?>,
        defaultKeyType: KeyType? = nil,
        requestedKeyType: KeyType? = nil,
        keyGroupID: UUID? = nil,
        requestID: UUID? = nil
    ) -> some View {
        modifier(ProtectedActionModifier(
            action: action,
            defaultKeyType: defaultKeyType,
            requestedKeyType: requestedKeyType,
            keyGroupID: keyGroupID,
            requestID: requestID
        ))
    }
}
