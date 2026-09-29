import Foundation
import OSLog
import SwiftData

final class AppBlockIntentPerformer: BlockIntentPerforming {
    private let container: ModelContainer
    private let screenTimeService: any ScreenTimeProviding
    private let timedUnblockService: TimedUnblockService
    private let scheduleService: ScheduleService
    private let syncsExternalSurfaces: Bool
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Intents")

    init(
        container: ModelContainer,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        scheduleService: ScheduleService,
        syncsExternalSurfaces: Bool = true
    ) {
        self.container = container
        self.screenTimeService = screenTimeService
        self.timedUnblockService = timedUnblockService
        self.scheduleService = scheduleService
        self.syncsExternalSurfaces = syncsExternalSurfaces
    }

    convenience init(container: ModelContainer, services: AppServices) {
        self.init(
            container: container,
            screenTimeService: services.screenTime,
            timedUnblockService: services.timedUnblock,
            scheduleService: services.schedule
        )
    }

    private var context: ModelContext { container.mainContext }

    func blockAll() throws -> BlockOutcome {
        logger.info("Block intent: all")
        let settings = try validatedSettings()
        guard let mainSelection = try context.fetch(FetchDescriptor<SelectedApps>()).first,
              !mainSelection.selection.isEmpty
              || (settings.enableCustomDomains && !mainSelection.customDomains.isEmpty)
        else { throw BlockIntentError.noAppsSelected }

        let status = screenTimeService.blockStatus(
            selection: mainSelection.selection,
            customDomains: settings.enableCustomDomains ? mainSelection.customDomains : []
        )
        let wasAlreadyBlocked = status == .all && timedUnblockService.activeUnblocks.isEmpty

        BlockActions.blockAll(
            mainSelection: mainSelection,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService,
            scheduleService: scheduleService
        )
        syncExternalSurfaces(settings: settings)
        return BlockOutcome(name: String(localized: "All Apps"), wasAlreadyBlocked: wasAlreadyBlocked)
    }

    func blockGroup(id: UUID) throws -> BlockOutcome {
        logger.info("Block intent: group")
        let settings = try validatedSettings()
        let descriptor = FetchDescriptor<AppGroup>(predicate: #Predicate { $0.id == id })
        guard let group = try context.fetch(descriptor).first else {
            throw BlockIntentError.groupNotFound
        }

        let status = screenTimeService.blockStatus(
            selection: group.selection,
            customDomains: settings.enableCustomDomains ? group.customDomains : []
        )
        let wasAlreadyBlocked = status == .all && !timedUnblockService.isGroupUnblockActive(groupId: id)

        BlockActions.blockGroup(
            group,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
        syncExternalSurfaces(settings: settings)
        return BlockOutcome(name: group.name, wasAlreadyBlocked: wasAlreadyBlocked)
    }

    private func validatedSettings() throws -> Settings {
        let settings = try context.fetch(FetchDescriptor<Settings>()).first
        try BlockActions.validate(
            isAuthorized: screenTimeService.isAuthorizedNow,
            hasCompletedOnboarding: settings?.hasCompletedOnboarding == true,
            keys: context.fetch(FetchDescriptor<Key>())
        )
        guard let settings else { throw BlockIntentError.setupIncomplete }
        return settings
    }

    private func syncExternalSurfaces(settings: Settings) {
        guard syncsExternalSurfaces else { return }
        let groups = (try? context.fetch(FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let keys = (try? context.fetch(FetchDescriptor<Key>())) ?? []
        WidgetSync.sync(groups: groups, keys: keys, settings: settings, screenTimeService: screenTimeService)
        LiveActivityManager.reconcile(
            timedUnblockService: timedUnblockService,
            groups: groups,
            isEnabled: settings.showTimedUnblockLiveActivity
        )
    }
}
