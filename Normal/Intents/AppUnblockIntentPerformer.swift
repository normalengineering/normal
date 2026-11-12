import Foundation
import OSLog
import SwiftData

final class AppUnblockIntentPerformer: UnblockIntentPerforming {
    private enum Target {
        case all(SelectedApps)
        case group(AppGroup)
    }

    private let intents: IntentContext
    private let unlockInbox: UnlockRequestInbox
    private let locationVerifier: BackgroundLocationVerifier
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
            timedUnblockService: timedUnblockService,
            syncsExternalSurfaces: syncsExternalSurfaces
        )
        self.unlockInbox = unlockInbox
        self.locationVerifier = locationVerifier
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
        let settings = try intents.validatedSettings()
        intents.timedUnblockService.refresh(screenTimeService: intents.screenTimeService)
        let target: Target = if let groupID = request.groupID {
            try .group(intents.group(id: groupID))
        } else {
            try .all(intents.mainSelection(settings: settings))
        }
        if isUnblocked(target, settings: settings) {
            return .alreadyUnblocked(name: name(of: target))
        }

        guard let duration = settings.duration(for: request.duration),
              (request.keyType ?? settings.defaultKeyType) == .location
        else { return .continueInApp }
        let location = try await locationVerifier.check(keys: Key.scoped(intents.keys(), toGroup: request.groupID))
        try Task.checkCancellation()
        switch location {
        case .verified:
            break
        case .outOfRange:
            throw UnblockIntentError.notAtUnlockLocation
        case .unavailable:
            return .continueInApp
        }

        do {
            try start(target, duration: duration, settings: settings)
        } catch {
            logger.error("Unblock intent failed to start: \(error.localizedDescription, privacy: .public)")
            throw UnblockIntentError.unblockFailed
        }
        intents.syncExternalSurfaces(settings: settings)
        return .unblocked(name: name(of: target), duration: duration)
    }

    func continueInApp(_ request: UnblockRequest) {
        unlockInbox.post(
            groupID: request.groupID,
            duration: request.duration,
            keyType: request.keyType ?? intents.defaultKeyType()
        )
    }

    private func name(of target: Target) -> String {
        switch target {
        case .all: String(localized: "All Apps")
        case let .group(group): group.name
        }
    }

    private func isUnblocked(_ target: Target, settings: Settings) -> Bool {
        let timedUnblock = intents.timedUnblockService
        switch target {
        case let .all(mainSelection):
            return !intents.blockStatus(of: mainSelection, settings: settings)
                .allowsUnblockAll(mainTimedUnblockActive: timedUnblock.isMainUnblockActive)
        case let .group(group):
            let status = intents.blockStatus(of: group, settings: settings)
            return status == .none
                || status.showsGroupTimedUnblock(
                    groupTimedUnblockActive: timedUnblock.isGroupUnblockActive(groupId: group.id)
                )
        }
    }

    private func start(_ target: Target, duration: TimedUnblockDuration, settings: Settings) throws {
        switch target {
        case let .all(mainSelection):
            try intents.timedUnblockService.startMain(
                duration: duration,
                mainSelection: mainSelection,
                settings: settings,
                screenTimeService: intents.screenTimeService
            )
        case let .group(group):
            try intents.timedUnblockService.startGroup(
                duration: duration,
                group: group,
                settings: settings,
                screenTimeService: intents.screenTimeService
            )
        }
    }
}
