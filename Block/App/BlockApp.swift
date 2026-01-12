import SwiftUI
import SwiftData

@main
struct BlockApp: App {
    @State private var screenTimeService = ScreenTimeService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(screenTimeService)
                .modelContainer(for: [AppGroup.self])
        }
    }
}
