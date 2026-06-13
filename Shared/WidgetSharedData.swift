import Foundation

struct WidgetGroupDTO: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let sortIndex: Int
}

enum WidgetBlockStatus: String, Sendable {
    case blocked
    case partial
    case unblocked
}

enum WidgetGroupState: Equatable, Sendable {
    case blocked
    case unblocked(until: Date?)

    var isUnblocked: Bool {
        if case .unblocked = self { true } else { false }
    }

    var countdownEnd: Date? {
        if case let .unblocked(until) = self { until } else { nil }
    }

    static func resolve(timedUnblockEnd: Date?, blockStatus: WidgetBlockStatus?, now: Date) -> WidgetGroupState {
        if let timedUnblockEnd {
            return timedUnblockEnd > now ? .unblocked(until: timedUnblockEnd) : .blocked
        }
        return blockStatus == .unblocked ? .unblocked(until: nil) : .blocked
    }
}

private struct WidgetUnblockStatusDTO: Codable {
    let id: String
    let endDate: Date
}

struct WidgetSharedStore: Sendable {
    private nonisolated(unsafe) let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: SharedConstants.appGroupID)
    }

    func saveGroups(_ groups: [WidgetGroupDTO]) {
        let data = try? PropertyListEncoder().encode(groups)
        defaults?.set(data, forKey: SharedConstants.DefaultsKey.widgetGroups)
    }

    func loadGroups() -> [WidgetGroupDTO] {
        guard let data = defaults?.data(forKey: SharedConstants.DefaultsKey.widgetGroups) else {
            return []
        }
        let groups = (try? PropertyListDecoder().decode([WidgetGroupDTO].self, from: data)) ?? []
        return groups.sorted { $0.sortIndex < $1.sortIndex }
    }

    func group(id: UUID) -> WidgetGroupDTO? {
        loadGroups().first { $0.id == id }
    }

    func saveKeyTypes(_ rawValues: [String]) {
        defaults?.set(rawValues, forKey: SharedConstants.DefaultsKey.widgetKeyTypes)
    }

    func loadKeyTypes() -> [String] {
        defaults?.stringArray(forKey: SharedConstants.DefaultsKey.widgetKeyTypes) ?? []
    }

    func saveBlockStatuses(_ statuses: [String: String]) {
        defaults?.set(statuses, forKey: SharedConstants.DefaultsKey.widgetBlockStatuses)
    }

    func blockStatus(forGroupId id: UUID) -> WidgetBlockStatus? {
        let raw = defaults?.dictionary(forKey: SharedConstants.DefaultsKey.widgetBlockStatuses) as? [String: String]
        return raw?[id.uuidString].flatMap(WidgetBlockStatus.init(rawValue:))
    }

    func timedUnblockEnd(forGroupId id: UUID) -> Date? {
        guard let data = defaults?.data(forKey: SharedConstants.DefaultsKey.timedUnblocks) else {
            return nil
        }
        let items = (try? PropertyListDecoder().decode([WidgetUnblockStatusDTO].self, from: data)) ?? []
        return items.first { $0.id == id.uuidString }?.endDate
    }

    func groupState(forGroupId id: UUID, now: Date = Date()) -> WidgetGroupState {
        WidgetGroupState.resolve(
            timedUnblockEnd: timedUnblockEnd(forGroupId: id),
            blockStatus: blockStatus(forGroupId: id),
            now: now
        )
    }
}

enum WidgetDeepLink {
    static let scheme = "normal"
    static let unlockHost = "unlock"
    static let blockHost = "block"
    static let groupQueryItem = "group"
    static let durationQueryItem = "duration"
    static let keyQueryItem = "key"

    static func unlockURL(groupID: UUID, durationSeconds: Int?, keyTypeRawValue: String?) -> URL {
        var items = [URLQueryItem(name: groupQueryItem, value: groupID.uuidString)]
        if let durationSeconds {
            items.append(URLQueryItem(name: durationQueryItem, value: String(durationSeconds)))
        }
        if let keyTypeRawValue {
            items.append(URLQueryItem(name: keyQueryItem, value: keyTypeRawValue))
        }
        return url(host: unlockHost, items: items)
    }

    static func blockURL(groupID: UUID) -> URL {
        url(host: blockHost, items: [URLQueryItem(name: groupQueryItem, value: groupID.uuidString)])
    }

    private static func url(host: String, items: [URLQueryItem]) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = items
        return components.url!
    }
}
