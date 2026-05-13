@testable import Normal
import Foundation
import SwiftData

@MainActor
func makeTestModelContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
        for: Key.self, Settings.self, BlockSchedule.self, SelectedApps.self, AppGroup.self,
        configurations: config
    )
}
