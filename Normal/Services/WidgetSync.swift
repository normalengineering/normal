import Foundation
import WidgetKit

enum WidgetSync {
    static func sync(
        groups: [AppGroup],
        keys: [Key],
        settings: Settings?,
        screenTimeService: any ScreenTimeProviding
    ) {
        let customDomainsEnabled = settings?.enableCustomDomains ?? false
        let blockStatuses = Dictionary(uniqueKeysWithValues: groups.map { group in
            (
                group.id.uuidString,
                screenTimeService.blockStatus(
                    selection: group.selection,
                    customDomains: customDomainsEnabled ? group.customDomains : []
                ).widget.rawValue
            )
        })
        let store = WidgetSharedStore()
        store.saveGroups(groups.map {
            WidgetGroupDTO(id: $0.id, name: $0.name, sortIndex: $0.sortIndex, detail: $0.selection.selectedTokenCounts)
        })
        store.saveKeyTypes(KeyType.selectable(registered: keys.map(\.type)).map(\.rawValue))
        store.saveBlockStatuses(blockStatuses)
        store.saveUnblockDurations((settings?.unblockDurations ?? TimedUnblockDuration.presets).map(\.seconds))
        reloadTimelines()
    }

    static func reloadTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
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
