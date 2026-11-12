import AppIntents

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
