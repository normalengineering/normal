import AppIntents

struct UnblockDurationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Unblock Duration")
    static let defaultQuery = UnblockDurationEntityQuery()

    static let appDefaultID = -1
    static let askEachTimeID = 0
    static let permanentID = -2

    /// Seconds, or one of the special ids above.
    let id: Int

    init(id: Int) {
        self.id = id
    }

    init(_ request: UnlockDurationRequest) {
        id = switch request {
        case .useDefault: Self.appDefaultID
        case .ask: Self.askEachTimeID
        case .permanent: Self.permanentID
        case let .fixed(duration): duration.seconds
        }
    }

    static func request(forID id: Int) -> UnlockDurationRequest? {
        switch id {
        case appDefaultID: .useDefault
        case askEachTimeID: .ask
        case permanentID: .permanent
        default: TimedUnblockDuration(validating: id).map(UnlockDurationRequest.fixed)
        }
    }

    var request: UnlockDurationRequest {
        Self.request(forID: id) ?? .ask
    }

    var displayRepresentation: DisplayRepresentation {
        switch request {
        case .useDefault: DisplayRepresentation(title: "Default Duration")
        case .ask: DisplayRepresentation(title: "Choose in Normal")
        case .permanent: DisplayRepresentation(title: "Until Manually Re-Blocked")
        case let .fixed(duration): DisplayRepresentation(title: "\(duration.label)")
        }
    }
}

struct UnblockDurationEntityQuery: EntityQuery {
    private let store = WidgetSharedStore()

    /// Resolves any valid id, not only ones still in the list, so a configured widget never silently resets.
    func entities(for identifiers: [Int]) async throws -> [UnblockDurationEntity] {
        identifiers
            .filter { UnblockDurationEntity.request(forID: $0) != nil }
            .map(UnblockDurationEntity.init(id:))
    }

    func suggestedEntities() async throws -> [UnblockDurationEntity] {
        let timed = store.loadUnblockDurations().map(UnlockDurationRequest.fixed)
        return ([.useDefault, .ask] + timed + [.permanent]).map(UnblockDurationEntity.init)
    }
}
