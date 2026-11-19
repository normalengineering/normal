import Foundation
import SwiftData

@testable import Normal

@MainActor
enum InMemoryModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema(NormalApp.models)
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        container.mainContext.autosaveEnabled = false
        return container
    }
}
