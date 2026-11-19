import FamilyControls
import Foundation

enum UnblockTarget: Identifiable {
    case all(SelectedApps)
    case group(AppGroup)

    var id: String {
        switch self {
        case .all: "all"
        case .group(let group): group.id.uuidString
        }
    }

    var group: AppGroup? {
        if case .group(let group) = self {
            return group
        }
        return nil
    }

    var groupID: UUID? {
        if case .group(let group) = self {
            return group.id
        }
        return nil
    }

    var name: String {
        switch self {
        case .all: String(localized: "All Apps")
        case .group(let group): group.name
        }
    }

    var selection: FamilyActivitySelection {
        switch self {
        case .all(let mainSelection): mainSelection.selection
        case .group(let group): group.selection
        }
    }

    func canUnblock(status: BlockStatus, timedUnblockService: TimedUnblockService) -> Bool {
        switch self {
        case .all:
            status.canUnblockAll(timedUnblockActive: timedUnblockService.isMainUnblockActive)
        case .group(let group):
            status.canUnblockGroup(timedUnblockActive: timedUnblockService.isGroupUnblockActive(groupId: group.id))
        }
    }

    func customDomains(settings: Settings) -> [String] {
        guard settings.enableCustomDomains else { return [] }
        return switch self {
        case .all(let mainSelection): mainSelection.customDomains
        case .group(let group): group.customDomains
        }
    }
}

extension TimedUnblockService {
    @discardableResult
    func start(
        _ grant: UnblockGrant,
        duration: TimedUnblockDuration,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding
    ) throws -> UnblockTiming {
        let target = grant.target
        switch target {
        case .all(let mainSelection):
            return try startMain(
                duration: duration,
                mainSelection: mainSelection,
                settings: settings,
                screenTimeService: screenTimeService
            )
        case .group(let group):
            return try startGroup(
                duration: duration,
                groupId: group.id,
                selection: group.selection,
                customDomains: target.customDomains(settings: settings),
                screenTimeService: screenTimeService
            )
        }
    }
}

extension ScreenTimeProviding {
    func blockStatus(of target: UnblockTarget, settings: Settings) -> BlockStatus {
        blockStatus(selection: target.selection, customDomains: target.customDomains(settings: settings))
    }

    func unblockPermanently(_ grant: UnblockGrant, settings: Settings) {
        let target = grant.target
        switch target {
        case .all:
            unblockAll(blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete)
        case .group:
            unblock(selection: target.selection, customDomains: target.customDomains(settings: settings))
        }
    }
}
