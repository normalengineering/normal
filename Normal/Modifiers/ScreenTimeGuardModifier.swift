import SwiftUI

struct ScreenTimeGuardModifier: ViewModifier {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Binding var action: (@MainActor () -> Void)?
    @State private var deferred: (@MainActor () -> Void)?

    func body(content: Content) -> some View {
        content.onChange(of: action != nil) { _, hasAction in
            guard hasAction, let pending = action else { return }
            if screenTimeService.authorizationState == .authorized { return }
            deferred = pending
            action = nil
            Task {
                if await screenTimeService.ensureAuthorized() {
                    action = deferred
                }
                deferred = nil
            }
        }
    }
}

extension View {
    func screenTimeGuard(action: Binding<(@MainActor () -> Void)?>) -> some View {
        modifier(ScreenTimeGuardModifier(action: action))
    }
}
