import SwiftUI

struct ContentView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    
    var body: some View {
        Group {
            switch screenTimeService.authorizationState {
            case .authorized:
                MainTabView()
            case .notAuthorized:
                PermissionRequestView()
            }
        }
    }
}
