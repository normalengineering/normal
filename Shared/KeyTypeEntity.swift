import AppIntents

struct KeyTypeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Key Type")
    static let defaultQuery = KeyTypeEntityQuery()

    let id: String

    var keyType: KeyType? {
        KeyType(rawValue: id)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(keyType?.label ?? id)")
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
