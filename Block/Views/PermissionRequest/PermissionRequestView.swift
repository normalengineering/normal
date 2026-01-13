import SwiftUI

struct PermissionRequestView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    var body: some View {
        ContentUnavailableView {
            Label("Permission Needed", systemImage: "lock.shield")
        } description: {
            Text("Block needs permission to manage your apps.")
        } actions: {
            Button("Authorize") {
                Task { await screenTimeService.requestAuthorization() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
