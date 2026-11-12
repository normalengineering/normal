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

    var selection: FamilyActivitySelection {
        switch self {
        case let .all(mainSelection): mainSelection.selection
        case let .group(group): group.selection
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
        _ target: UnblockTarget,
        duration: TimedUnblockDuration,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding
    ) throws {
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
    func unblockPermanently(_ target: UnblockTarget, settings: Settings) {
        switch target {
        case .all:
            unblockAll(blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete)
        case .group:
            unblock(selection: target.selection, customDomains: target.customDomains(settings: settings))
        }
    }
}
