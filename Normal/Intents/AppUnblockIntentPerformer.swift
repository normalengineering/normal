import Foundation
import OSLog
import SwiftData

final class AppUnblockIntentPerformer: UnblockIntentPerforming {
    private let intents: IntentContext
    private let unlockInbox: UnlockRequestInbox
    private let locationVerifier: BackgroundLocationVerifier
    private let syncsExternalSurfaces: Bool
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Intents")

    init(
        container: ModelContainer,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        unlockInbox: UnlockRequestInbox,
        locationVerifier: BackgroundLocationVerifier,
        syncsExternalSurfaces: Bool = true
    ) {
        intents = IntentContext(
            container: container,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
        self.unlockInbox = unlockInbox
        self.locationVerifier = locationVerifier
        self.syncsExternalSurfaces = syncsExternalSurfaces
    }

    convenience init(container: ModelContainer, services: AppServices) {
        self.init(
            container: container,
            screenTimeService: services.screenTime,
            timedUnblockService: services.timedUnblock,
            unlockInbox: services.unlockInbox,
            locationVerifier: BackgroundLocationVerifier(provider: LocationService.shared)
        )
    }

    func unblock(_ request: UnblockRequest) async throws -> UnblockOutcome {
        logger.info("Unblock intent: \(request.groupID == nil ? "all" : "group", privacy: .public)")
        let settings: Settings
        switch try readiness(for: request) {
        case let .settled(outcome):
            return outcome
        case let .ready(readySettings, _):
            settings = readySettings
        }

        let keys = try Key.scoped(intents.keys(), toGroup: request.groupID)
        guard keyType(for: request, keys: keys, settings: settings) == .location,
              settings.unblockLength(for: request.duration) != nil
        else { return .continueInApp(.checkKey) }
        let radiusKind = Key.existingLocationKind(in: keys) ?? .unblock

        let location = await locationVerifier.check(keys: keys)
        try Task.checkCancellation()
        switch location {
        case .verified:
            break
        case .outOfRange:
            throw UnblockIntentError.notAtLocation(radiusKind)
        case .needsAlways:
            return .continueInApp(.backgroundLocationOff)
        case .needsPrecise:
            return .continueInApp(.preciseLocationOff)
        case .inconclusive:
            return .continueInApp(.noLocationFix)
        case .noLocationKey:
            return .continueInApp(.checkKey)
        }

        switch try readiness(for: request) {
        case let .settled(outcome):
            return outcome
        case let .ready(settings, target):
            guard let length = settings.unblockLength(for: request.duration) else { return .continueInApp(.checkKey) }
            return try start(target, for: length, settings: settings)
        }
    }

    func continueInApp(_ request: UnblockRequest) {
        unlockInbox.post(UnblockRequest(
            groupID: request.groupID,
            duration: request.duration,
            keyType: keyType(
                for: request,
                keys: Key.scoped((try? intents.keys()) ?? [], toGroup: request.groupID),
                settings: intents.settings()
            )
        ))
    }

    private enum Readiness {
        case ready(Settings, UnblockTarget)
        case settled(UnblockOutcome)
    }

    private func readiness(for request: UnblockRequest) throws -> Readiness {
        let settings = try intents.validatedSettings(requiringGlobalKey: false)
        intents.timedUnblockService.refresh(screenTimeService: intents.screenTimeService)
        let target = try intents.target(groupID: request.groupID, settings: settings)
        let status = intents.screenTimeService.blockStatus(of: target, settings: settings)
        guard target.canUnblock(status: status, timedUnblockService: intents.timedUnblockService) else {
            return .settled(status == .none ? .alreadyUnblocked(name: target.name) : .timedUnblockRunning(name: target.name))
        }
        return .ready(settings, target)
    }

    private func start(_ target: UnblockTarget, for length: UnblockLength, settings: Settings) throws -> UnblockOutcome {
        do {
            try BlockActions.unblock(
                target,
                for: length,
                settings: settings,
                screenTimeService: intents.screenTimeService,
                timedUnblockService: intents.timedUnblockService
            )
        } catch {
            logger.error("Unblock intent failed to start: \(error.localizedDescription, privacy: .public)")
            throw UnblockIntentError.unblockFailed
        }
        if syncsExternalSurfaces {
            intents.syncExternalSurfaces(settings: settings)
        }
        return .unblocked(name: target.name, length: length)
    }

    private func keyType(for request: UnblockRequest, keys: [Key], settings: Settings?) -> KeyType? {
        KeySelectLogic.shortcutKeyType(
            requested: request.keyType,
            defaultKeyType: settings?.defaultKeyType,
            availableKeyTypes: KeyType.selectable(registered: keys.map(\.type))
        )
    }
}
