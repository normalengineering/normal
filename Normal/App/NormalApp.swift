import SwiftData
import SwiftUI

@main
struct NormalApp: App {
    let modelContainer: ModelContainer

    init() {
        let container = try! ModelContainer(
            for: AppGroup.self,
                 SelectedApps.self,
                 Key.self,
                 BlockSchedule.self,
                 Settings.self
        )

        let context = container.mainContext
        let descriptor = FetchDescriptor<Settings>()
        if (try? context.fetchCount(descriptor)) == 0 {
            context.insert(Settings())
        }

        self.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            AppContainer()
        }
        .modelContainer(modelContainer)
    }
}
