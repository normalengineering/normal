import SwiftData
import SwiftUI

@main
struct BlockApp: App {
    @State private var screenTimeService = ScreenTimeService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(screenTimeService)
                .modelContainer(for: [AppGroup.self, SelectedApps.self])
        }
    }
}
