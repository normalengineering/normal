import Foundation
import SwiftData

struct IntentContext {
    let container: ModelContainer
    let screenTimeService: any ScreenTimeProviding
    let timedUnblockService: TimedUnblockService
    let syncsExternalSurfaces: Bool

    private var context: ModelContext {
        container.mainContext
    }

    func validatedSettings() throws -> Settings {
        let settings = try context.fetch(FetchDescriptor<Settings>()).first
        try BlockActions.validate(
            isAuthorized: screenTimeService.isAuthorizedNow,
            hasCompletedOnboarding: settings?.hasCompletedOnboarding == true,
            keys: keys()
        )
        guard let settings else { throw BlockIntentError.setupIncomplete }
        return settings
    }

    func keys() throws -> [Key] {
        try context.fetch(FetchDescriptor<Key>())
    }

    func defaultKeyType() -> KeyType? {
        (try? context.fetch(FetchDescriptor<Settings>()).first)?.defaultKeyType
    }

    func mainSelection(settings: Settings) throws -> SelectedApps {
        guard let mainSelection = try context.fetch(FetchDescriptor<SelectedApps>()).first,
              !mainSelection.selection.isEmpty
              || (settings.enableCustomDomains && !mainSelection.customDomains.isEmpty)
        else { throw BlockIntentError.noAppsSelected }
        return mainSelection
    }

    func group(id: UUID) throws -> AppGroup {
        let descriptor = FetchDescriptor<AppGroup>(predicate: #Predicate { $0.id == id })
        guard let group = try context.fetch(descriptor).first else {
            throw BlockIntentError.groupNotFound
        }
        return group
    }

    func blockStatus(of mainSelection: SelectedApps, settings: Settings) -> BlockStatus {
        screenTimeService.blockStatus(
            selection: mainSelection.selection,
            customDomains: settings.enableCustomDomains ? mainSelection.customDomains : []
        )
    }

    func blockStatus(of group: AppGroup, settings: Settings) -> BlockStatus {
        screenTimeService.blockStatus(
            selection: group.selection,
            customDomains: settings.enableCustomDomains ? group.customDomains : []
        )
    }

    func syncExternalSurfaces(settings: Settings) {
        guard syncsExternalSurfaces else { return }
        let groups = (try? context.fetch(FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let keys = (try? keys()) ?? []
        WidgetSync.sync(groups: groups, keys: keys, settings: settings, screenTimeService: screenTimeService)
        LiveActivityManager.reconcile(
            timedUnblockService: timedUnblockService,
            groups: groups,
            isEnabled: settings.showTimedUnblockLiveActivity
        )
    }
}
