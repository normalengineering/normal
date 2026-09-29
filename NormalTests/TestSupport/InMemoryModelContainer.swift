import Foundation
@testable import Normal
import SwiftData

@MainActor
enum InMemoryModelContainer {
    static func make() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Key.self,
            Settings.self,
            BlockSchedule.self,
            SelectedApps.self,
            AppGroup.self,
            configurations: config
        )
        container.mainContext.autosaveEnabled = false
        return container
    }
}
