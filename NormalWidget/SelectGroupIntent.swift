import AppIntents
import WidgetKit

struct SelectGroupIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Unlock"
    static let description = IntentDescription("Choose a group to unlock via the Home Screen.")

    @Parameter(title: "Group")
    var group: GroupEntity?

    @Parameter(title: "Unblock Duration")
    var unblockDuration: UnblockDurationEntity?

    @Parameter(title: "Legacy Duration")
    var duration: UnblockDuration?

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Unlock \(\.$group)") {
            \.$unblockDuration
            \.$keyType
        }
    }

    var durationRequest: UnlockDurationRequest {
        if let unblockDuration { return unblockDuration.request }
        return duration
            .flatMap { TimedUnblockDuration(validating: $0.rawValue) }
            .map(UnlockDurationRequest.fixed) ?? .useDefault
    }
}

struct UnblockDurationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Unblock Duration")
    static let defaultQuery = UnblockDurationEntityQuery()

    static let appDefaultID = -1
    static let askEachTimeID = 0

    /// Seconds, or one of the special ids above.
    let id: Int

    static let appDefault = UnblockDurationEntity(id: appDefaultID)
    static let askEachTime = UnblockDurationEntity(id: askEachTimeID)

    init(id: Int) {
        self.id = id
    }

    init(_ duration: TimedUnblockDuration) {
        id = duration.seconds
    }

    var request: UnlockDurationRequest {
        switch id {
        case Self.appDefaultID: .useDefault
        case Self.askEachTimeID: .ask
        default: TimedUnblockDuration(validating: id).map(UnlockDurationRequest.fixed) ?? .ask
        }
    }

    var displayRepresentation: DisplayRepresentation {
        switch id {
        case Self.appDefaultID: DisplayRepresentation(title: "App Default")
        case Self.askEachTimeID: DisplayRepresentation(title: "Ask Each Time")
        default: DisplayRepresentation(
                title: "\(TimedUnblockDuration(validating: id)?.label ?? String(id))"
            )
        }
    }
}

struct UnblockDurationEntityQuery: EntityQuery {
    private let store = WidgetSharedStore()

    /// Resolves any valid id, not only ones still in the list, so a configured widget never silently resets.
    func entities(for identifiers: [Int]) async throws -> [UnblockDurationEntity] {
        identifiers.compactMap { id in
            let isSpecial = id == UnblockDurationEntity.appDefaultID || id == UnblockDurationEntity.askEachTimeID
            return isSpecial || TimedUnblockDuration.isValid(id) ? UnblockDurationEntity(id: id) : nil
        }
    }

    func suggestedEntities() async throws -> [UnblockDurationEntity] {
        [.appDefault, .askEachTime] + store.loadUnblockDurations().map(UnblockDurationEntity.init)
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
