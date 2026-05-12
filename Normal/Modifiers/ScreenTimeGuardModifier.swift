import SwiftUI

struct ScreenTimeGuardModifier: ViewModifier {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Binding var action: (@MainActor () -> Void)?
    @State private var showPermissionAlert = false
    @State private var guardedAction: (@MainActor () -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: action != nil) { _, hasAction in
                guard hasAction, let pending = action else { return }
                if screenTimeService.authorizationState == .authorized {
                    return
                }
                guardedAction = pending
                action = nil
                showPermissionAlert = true
            }
            .alert("Screen Time Permission Needed", isPresented: $showPermissionAlert) {
                Button("Grant Permission") {
                    Task {
                        await screenTimeService.requestAuthorization()
                        if screenTimeService.authorizationState == .authorized {
                            action = guardedAction
                        }
                        guardedAction = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    guardedAction = nil
                }
            } message: {
                Text("Normal needs Screen Time permission to block and unblock apps.")
            }
    }
}

extension View {
    func screenTimeGuard(action: Binding<(@MainActor () -> Void)?>) -> some View {
        modifier(ScreenTimeGuardModifier(action: action))
    }
}
