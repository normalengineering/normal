import FamilyControls
import Foundation

enum UnblockTarget: Identifiable {
    case all(SelectedApps)
    case group(AppGroup)

    var id: String {
        switch self {
        case .all: "all"
        case let .group(group): group.id.uuidString
        }
    }

    var groupID: UUID? {
        if case let .group(group) = self {
            return group.id
        }
        return nil
    }

    var name: String {
        switch self {
        case .all: String(localized: "All Apps")
        case let .group(group): group.name
        }
    }

    var selection: FamilyActivitySelection {
        switch self {
        case let .all(mainSelection): mainSelection.selection
        case let .group(group): group.selection
        }
    }

    func canUnblock(status: BlockStatus, timedUnblockService: TimedUnblockService) -> Bool {
        switch self {
        case .all:
            status.canUnblockAll(timedUnblockActive: timedUnblockService.isMainUnblockActive)
        case let .group(group):
            status.canUnblockGroup(timedUnblockActive: timedUnblockService.isGroupUnblockActive(groupId: group.id))
        }
    }

    func customDomains(settings: Settings) -> [String] {
        guard settings.enableCustomDomains else { return [] }
        return switch self {
        case let .all(mainSelection): mainSelection.customDomains
        case let .group(group): group.customDomains
        }
    }
}

extension TimedUnblockService {
    func start(
        _ grant: UnblockGrant,
        duration: TimedUnblockDuration,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding
    ) throws {
        let target = grant.target
        switch target {
        case let .all(mainSelection):
            try startMain(
                duration: duration,
                mainSelection: mainSelection,
                settings: settings,
                screenTimeService: screenTimeService
            )
        case let .group(group):
            try startGroup(
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
