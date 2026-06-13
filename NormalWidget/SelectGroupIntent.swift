import AppIntents
import WidgetKit

struct SelectGroupIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Unlock"
    static let description = IntentDescription("Choose a group to unlock via the Home Screen.")

    @Parameter(title: "Group")
    var group: GroupEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDuration?

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Unlock \(\.$group)") {
            \.$duration
            \.$keyType
        }
    }
}

struct GroupEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Group")
    static let defaultQuery = GroupEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GroupEntityQuery: EntityQuery {
    private let store = WidgetSharedStore()

    func entities(for identifiers: [UUID]) async throws -> [GroupEntity] {
        store.loadGroups()
            .filter { identifiers.contains($0.id) }
            .map { GroupEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        store.loadGroups().map { GroupEntity(id: $0.id, name: $0.name) }
    }
}

struct KeyTypeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Key Type")
    static let defaultQuery = KeyTypeEntityQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(KeyType(rawValue: id)?.label ?? id)")
    }
}

struct KeyTypeEntityQuery: EntityQuery {
    private let store = WidgetSharedStore()

    func entities(for identifiers: [String]) async throws -> [KeyTypeEntity] {
        store.loadKeyTypes()
            .filter { identifiers.contains($0) }
            .map { KeyTypeEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [KeyTypeEntity] {
        store.loadKeyTypes().map { KeyTypeEntity(id: $0) }
    }
}
