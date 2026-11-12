import FamilyControls
import Foundation
import OSLog
import SwiftData

final class AppUnblockIntentPerformer: UnblockIntentPerforming {
    private struct Target {
        let name: String
        let groupID: UUID?
        let selection: FamilyActivitySelection
        let customDomains: [String]
        let isUnblocked: Bool
    }

    private let container: ModelContainer
    private let screenTimeService: any ScreenTimeProviding
    private let timedUnblockService: TimedUnblockService
    private let navigation: NavigationCoordinator
    private let locationVerifier: BackgroundLocationVerifier
    private let syncsExternalSurfaces: Bool
    private let logger = Logger(subsystem: "com.normalengineering.normal", category: "Intents")

    init(
        container: ModelContainer,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService,
        navigation: NavigationCoordinator,
        locationVerifier: BackgroundLocationVerifier,
        syncsExternalSurfaces: Bool = true
    ) {
        self.container = container
        self.screenTimeService = screenTimeService
        self.timedUnblockService = timedUnblockService
        self.navigation = navigation
        self.locationVerifier = locationVerifier
        self.syncsExternalSurfaces = syncsExternalSurfaces
    }

    convenience init(container: ModelContainer, services: AppServices) {
        self.init(
            container: container,
            screenTimeService: services.screenTime,
            timedUnblockService: services.timedUnblock,
            navigation: services.navigation,
            locationVerifier: BackgroundLocationVerifier(provider: LocationService.shared)
        )
    }

    private var context: ModelContext {
        container.mainContext
    }

    func unblock(_ request: UnblockRequest) async throws -> UnblockOutcome {
        logger.info("Unblock intent: \(request.groupID == nil ? "all" : "group", privacy: .public)")
        let settings = try validatedSettings()
        let target = try target(for: request.groupID, settings: settings)
        if target.isUnblocked {
            return .alreadyUnblocked(name: target.name)
        }

        guard let duration = settings.duration(for: request.duration), request.keyType == .location else {
            return .continueInApp
        }
        let keys = try Key.scoped(context.fetch(FetchDescriptor<Key>()), toGroup: request.groupID)
        switch await locationVerifier.check(keys: keys) {
        case .verified:
            break
        case .outOfRange:
            throw UnblockIntentError.notAtUnlockLocation
        case .unavailable:
            return .continueInApp
        }

        try start(target, duration: duration, settings: settings)
        syncExternalSurfaces(settings: settings)
        return .unblocked(name: target.name, duration: duration)
    }

    func continueInApp(_ request: UnblockRequest) {
        if let groupID = request.groupID {
            navigation.requestGroupUnlock(groupID: groupID, duration: request.duration, keyType: request.keyType)
        } else {
            navigation.requestMainUnlock(duration: request.duration, keyType: request.keyType)
        }
    }

    private func target(for groupID: UUID?, settings: Settings) throws -> Target {
        if let groupID {
            let descriptor = FetchDescriptor<AppGroup>(predicate: #Predicate { $0.id == groupID })
            guard let group = try context.fetch(descriptor).first else {
                throw BlockIntentError.groupNotFound
            }
            let customDomains = settings.enableCustomDomains ? group.customDomains : []
            let status = screenTimeService.blockStatus(selection: group.selection, customDomains: customDomains)
            return Target(
                name: group.name,
                groupID: groupID,
                selection: group.selection,
                customDomains: customDomains,
                isUnblocked: status == .none
                    || (timedUnblockService.isGroupUnblockActive(groupId: groupID) && status != .all)
            )
        }

        guard let mainSelection = try context.fetch(FetchDescriptor<SelectedApps>()).first,
              !mainSelection.selection.isEmpty
              || (settings.enableCustomDomains && !mainSelection.customDomains.isEmpty)
        else { throw BlockIntentError.noAppsSelected }
        let customDomains = settings.enableCustomDomains ? mainSelection.customDomains : []
        let status = screenTimeService.blockStatus(selection: mainSelection.selection, customDomains: customDomains)
        return Target(
            name: String(localized: "All Apps"),
            groupID: nil,
            selection: mainSelection.selection,
            customDomains: customDomains,
            isUnblocked: status == .none || timedUnblockService.isMainUnblockActive
        )
    }

    private func start(_ target: Target, duration: TimedUnblockDuration, settings: Settings) throws {
        if let groupID = target.groupID {
            try timedUnblockService.startGroup(
                duration: duration,
                groupId: groupID,
                selection: target.selection,
                customDomains: target.customDomains,
                screenTimeService: screenTimeService
            )
        } else {
            try timedUnblockService.startMain(
                duration: duration,
                selection: target.selection,
                customDomains: target.customDomains,
                screenTimeService: screenTimeService,
                blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
            )
        }
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
        IntentSurfaceSync.sync(
            context: context,
            settings: settings,
            screenTimeService: screenTimeService,
            timedUnblockService: timedUnblockService
        )
    }
}
