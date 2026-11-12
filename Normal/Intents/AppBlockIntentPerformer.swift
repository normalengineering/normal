import Foundation
import OSLog
import SwiftData

final class AppBlockIntentPerformer: BlockIntentPerforming {
    private let intents: IntentContext
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Intents")

    init(
        container: ModelContainer,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        syncsExternalSurfaces: Bool = true
    ) {
        intents = IntentContext(
            container: container,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService,
            syncsExternalSurfaces: syncsExternalSurfaces
        )
    }

    convenience init(container: ModelContainer, services: AppServices) {
        self.init(
            container: container,
            screenTimeService: services.screenTime,
            timedUnblockService: services.timedUnblock
        )
    }

    func blockAll() throws -> BlockOutcome {
        logger.info("Block intent: all")
        let settings = try intents.validatedSettings()
        let mainSelection = try intents.mainSelection(settings: settings)
        let wasAlreadyBlocked = intents.blockStatus(of: mainSelection, settings: settings) == .all
            && intents.timedUnblockService.activeUnblocks.isEmpty

        BlockActions.blockAll(
            mainSelection: mainSelection,
            settings: settings,
            screenTimeService: intents.screenTimeService,
            timedUnblockService: intents.timedUnblockService
        )
        intents.syncExternalSurfaces(settings: settings)
        return BlockOutcome(name: String(localized: "All Apps"), wasAlreadyBlocked: wasAlreadyBlocked)
    }

    func blockGroup(id: UUID) throws -> BlockOutcome {
        logger.info("Block intent: group")
        let settings = try intents.validatedSettings()
        let group = try intents.group(id: id)
        let wasAlreadyBlocked = intents.blockStatus(of: group, settings: settings) == .all
            && !intents.timedUnblockService.isGroupUnblockActive(groupId: id)

        BlockActions.blockGroup(
            group,
            settings: settings,
            screenTimeService: intents.screenTimeService,
            timedUnblockService: intents.timedUnblockService
        )
        intents.syncExternalSurfaces(settings: settings)
        return BlockOutcome(name: group.name, wasAlreadyBlocked: wasAlreadyBlocked)
    }
}
