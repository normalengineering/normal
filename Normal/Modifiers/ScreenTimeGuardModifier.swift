import SwiftUI

struct ScreenTimeGuardModifier: ViewModifier {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Binding var action: ProtectedAction?
    @State private var deferred: ProtectedAction?

    func body(content: Content) -> some View {
        content.onChange(of: action != nil) { _, hasAction in
            guard hasAction, let pending = action else { return }
            if screenTimeService.authorizationState == .authorized {
                return
            }
            deferred = pending
            action = nil
            Task {
                if await screenTimeService.ensureAuthorized(), action == nil {
                    action = deferred
                }
                deferred = nil
            }
        }
    }
}

extension View {
    func screenTimeGuard(action: Binding<ProtectedAction?>) -> some View {
        modifier(ScreenTimeGuardModifier(action: action))
    }
}
