import SwiftData
import SwiftUI

@main
struct NormalApp: App {
    var body: some Scene {
        WindowGroup {
            AppContainer()
                .modelContainer(for: [
                    AppGroup.self,
                    SelectedApps.self,
                    Key.self,
                    BlockSchedule.self,
                ])
        }
    }
}
