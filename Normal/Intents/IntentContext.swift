import Foundation
import SwiftData

struct IntentContext {
    let container: ModelContainer
    let screenTimeService: any ScreenTimeProviding
    let timedUnblockService: TimedUnblockService

    private var context: ModelContext {
        container.mainContext
    }

    func validatedSettings(requiringGlobalKey: Bool) throws -> Settings {
        let settings = try context.fetch(FetchDescriptor<Settings>()).first
        let hasCompletedOnboarding = settings?.hasCompletedOnboarding == true
        if requiringGlobalKey {
            try BlockActions.validate(
                isAuthorized: screenTimeService.isAuthorizedNow,
                hasCompletedOnboarding: hasCompletedOnboarding,
                keys: keys()
            )
        } else {
            try BlockActions.validateSetup(
                isAuthorized: screenTimeService.isAuthorizedNow,
                hasCompletedOnboarding: hasCompletedOnboarding
            )
        }
        guard let settings else { throw BlockIntentError.setupIncomplete }
        return settings
    }

    func settings() -> Settings? {
        try? context.fetch(FetchDescriptor<Settings>()).first
    }

    func keys() throws -> [Key] {
        try context.fetch(FetchDescriptor<Key>())
    }

    func target(groupID: UUID?, settings: Settings) throws -> UnblockTarget {
        if let groupID {
            return try .group(group(id: groupID))
        }
        return try .all(mainSelection(settings: settings))
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

    func syncExternalSurfaces(settings: Settings) {
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
