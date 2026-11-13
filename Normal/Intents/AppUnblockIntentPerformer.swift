import Foundation
import OSLog
import SwiftData

final class AppUnblockIntentPerformer: UnblockIntentPerforming {
    private let intents: IntentContext
    private let unlockInbox: UnlockRequestInbox
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Intents")

    init(
        container: ModelContainer,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        unlockInbox: UnlockRequestInbox
    ) {
        intents = IntentContext(
            container: container,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
        self.unlockInbox = unlockInbox
    }

    convenience init(container: ModelContainer, services: AppServices) {
        self.init(
            container: container,
            screenTimeService: services.screenTime,
            timedUnblockService: services.timedUnblock,
            unlockInbox: services.unlockInbox
        )
    }

    func unblock(_ request: UnblockRequest) throws -> UnblockOutcome {
        logger.info("Unblock intent: \(request.groupID == nil ? "all" : "group", privacy: .public)")
        let settings = try intents.validatedSettings(requiringGlobalKey: false)
        intents.timedUnblockService.refresh(screenTimeService: intents.screenTimeService)
        let target = try intents.target(groupID: request.groupID, settings: settings)
        let status = intents.screenTimeService.blockStatus(of: target, settings: settings)
        guard target.canUnblock(status: status, timedUnblockService: intents.timedUnblockService) else {
            return status == .none ? .alreadyUnblocked(name: target.name) : .timedUnblockRunning(name: target.name)
        }
        return .continueInApp
    }

    func continueInApp(_ request: UnblockRequest) {
        unlockInbox.post(UnblockRequest(
            groupID: request.groupID,
            duration: request.duration,
            keyType: keyType(for: request)
        ))
    }

    private func keyType(for request: UnblockRequest) -> KeyType? {
        let keys = Key.scoped((try? intents.keys()) ?? [], toGroup: request.groupID)
        return KeySelectLogic.shortcutKeyType(
            requested: request.keyType,
            defaultKeyType: intents.settings()?.defaultKeyType,
            availableKeyTypes: KeyType.selectable(registered: keys.map(\.type))
        )
    }
}
