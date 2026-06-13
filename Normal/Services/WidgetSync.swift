import Foundation
import WidgetKit

enum WidgetSync {
    static func sync(
        groups: [AppGroup],
        availableKeyTypes: [KeyType],
        blockStatuses: [String: String]
    ) {
        let store = WidgetSharedStore()
        store.saveGroups(groups.map { WidgetGroupDTO(id: $0.id, name: $0.name, sortIndex: $0.sortIndex) })
        store.saveKeyTypes(availableKeyTypes.map(\.rawValue))
        store.saveBlockStatuses(blockStatuses)
        reloadTimelines()
    }

    static func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension BlockStatus {
    var widget: WidgetBlockStatus {
        switch self {
        case .all: .blocked
        case .some: .partial
        case .none: .unblocked
        }
    }
}
