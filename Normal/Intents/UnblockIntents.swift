import AppIntents
import Foundation

nonisolated extension UnblockRequest {
    init(group: GroupEntity?, keyType: KeyTypeEntity?, duration: UnblockDurationEntity?) {
        self.init(
            groupID: group?.id,
            duration: duration?.request ?? .useDefault,
            keyType: keyType?.keyType
        )
    }
}

enum UnblockOutcome: Equatable, Sendable {
    case alreadyUnblocked(name: String)
    case timedUnblockRunning(name: String)
    case continueInApp
}

protocol UnblockIntentPerforming: Sendable {
    @MainActor func unblock(_ request: UnblockRequest) throws -> UnblockOutcome
    @MainActor func continueInApp(_ request: UnblockRequest)
}

enum UnblockIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case openNormal

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .openNormal: "Open Normal to unblock."
        }
    }
}

struct UnblockAllIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock All Apps"
    static let description = IntentDescription(
        "Opens Normal to check your key, then unblocks the apps and websites selected in Normal. With no Key Type or Unblock Duration, Normal uses your defaults."
    )

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDurationEntity?

    @Dependency private var performer: any UnblockIntentPerforming

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Unblock all apps with \(\.$keyType), \(\.$duration)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let request = UnblockRequest(group: nil, keyType: keyType, duration: duration)
        switch try await performer.unblock(request) {
        case .alreadyUnblocked:
            return .result(dialog: "All selected apps are already unblocked.")
        case .timedUnblockRunning:
            return .result(dialog: "A timed unblock is already running for all apps.")
        case .continueInApp:
            return try await continueInApp(
                request,
                performer: performer,
                fallback: OpenUnblockIntent(group: nil, keyType: keyType, duration: duration)
            )
        }
    }
}

struct UnblockGroupIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock Group"
    static let description = IntentDescription(
        "Opens Normal to check your key, then unblocks one of your Normal groups. With no Key Type or Unblock Duration, Normal uses your defaults."
    )

    @Parameter(title: "Group", requestValueDialog: "Which group should Normal unblock?")
    var group: GroupEntity

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDurationEntity?

    @Dependency private var performer: any UnblockIntentPerforming

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        [.background, .foreground(.dynamic)]
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Unblock \(\.$group) with \(\.$keyType), \(\.$duration)")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let request = UnblockRequest(group: group, keyType: keyType, duration: duration)
        switch try await performer.unblock(request) {
        case let .alreadyUnblocked(name):
            return .result(dialog: "\(name) is already unblocked.")
        case let .timedUnblockRunning(name):
            return .result(dialog: "A timed unblock is already running for \(name).")
        case .continueInApp:
            return try await continueInApp(
                request,
                performer: performer,
                fallback: OpenUnblockIntent(group: group, keyType: keyType, duration: duration)
            )
        }
    }
}

struct OpenUnblockIntent: AppIntent {
    static let title: LocalizedStringResource = "Unblock in Normal"

    static var isDiscoverable: Bool {
        false
    }

    static var openAppWhenRun: Bool {
        true
    }

    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Parameter(title: "Group")
    var group: GroupEntity?

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDurationEntity?

    @Dependency private var performer: any UnblockIntentPerforming

    init() {}

    init(group: GroupEntity?, keyType: KeyTypeEntity?, duration: UnblockDurationEntity?) {
        self.group = group
        self.keyType = keyType
        self.duration = duration
    }

    func perform() async throws -> some IntentResult {
        await performer.continueInApp(UnblockRequest(group: group, keyType: keyType, duration: duration))
        return .result()
    }
}

private extension AppIntent {
    func continueInApp(
        _ request: UnblockRequest,
        performer: any UnblockIntentPerforming,
        fallback: OpenUnblockIntent
    ) async throws -> IntentResultContainer<Never, Never, Never, IntentDialog> {
        if #available(iOS 26.0, *) {
            if systemContext.currentMode == .background {
                guard systemContext.currentMode.canContinueInForeground else {
                    performer.continueInApp(request)
                    throw UnblockIntentError.openNormal
                }
                try await continueInForeground("Open Normal to check your key?", alwaysConfirm: false)
            }
            performer.continueInApp(request)
            return .result(dialog: "").withoutDialog
        }
        if #available(iOS 18.2, *) {
            return .result(opensIntent: fallback, dialog: "").withoutDialog
        }
        performer.continueInApp(request)
        throw UnblockIntentError.openNormal
    }
}

private extension IntentResultContainer<Never, Never, Never, IntentDialog> {
    var withoutDialog: Self {
        var result = self
        result.dialog = nil
        return result
    }
}
