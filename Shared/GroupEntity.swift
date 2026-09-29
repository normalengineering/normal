import AppIntents
import Foundation

/// A user group, as seen by widgets, controls and Shortcuts. Backed by the App Group mirror that
/// `WidgetSync` writes, because extensions can't open the SwiftData store.
struct GroupEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Group",
        numericFormat: "\(placeholder: .int) groups"
    )
    static let defaultQuery = GroupEntityQuery()

    let id: UUID
    let name: String
    /// What the group contains, e.g. "3 Apps, 1 Website". Shown under the name in pickers.
    let detail: String?

    init(dto: WidgetGroupDTO) {
        id = dto.id
        name = dto.name
        detail = dto.detail
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: detail.map { "\($0)" },
            image: DisplayRepresentation.Image(systemName: "square.stack.fill")
        )
    }
}

/// A plain `EntityQuery` on purpose: `EnumerableEntityQuery` / `EntityPropertyQuery` make Shortcuts
/// generate a "Find Group" action, which is clutter for this app.
struct GroupEntityQuery: EntityQuery {
    private let store = WidgetSharedStore()

    func entities(for identifiers: [UUID]) async throws -> [GroupEntity] {
        store.loadGroups()
            .filter { identifiers.contains($0.id) }
            .map(GroupEntity.init(dto:))
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        store.loadGroups().map(GroupEntity.init(dto:))
    }
}
