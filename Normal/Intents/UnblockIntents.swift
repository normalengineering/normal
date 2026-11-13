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
    case unblocked(name: String, length: UnblockLength)
    case alreadyUnblocked(name: String)
    case timedUnblockRunning(name: String)
    case continueInApp(HandOffReason)
}

enum HandOffReason: Equatable, Sendable {
    case checkKey
    case backgroundLocationOff
    case preciseLocationOff
    case noLocationFix

    var prompt: LocalizedStringResource {
        switch self {
        case .checkKey: "Open Normal to check your key?"
        case .backgroundLocationOff: "Background Location is off. Open Normal to check your location?"
        case .preciseLocationOff: "Precise Location is off. Open Normal to check your location?"
        case .noLocationFix: "Couldn't confirm your location. Open Normal to check it?"
        }
    }

    var notice: LocalizedStringResource? {
        switch self {
        case .checkKey: nil
        case .backgroundLocationOff: "Background Location is off, so Normal will check your location."
        case .preciseLocationOff: "Precise Location is off, so Normal will check your location."
        case .noLocationFix: "Couldn't confirm your location, so Normal will check it."
        }
    }
}

protocol UnblockIntentPerforming: Sendable {
    @MainActor func unblock(_ request: UnblockRequest) async throws -> UnblockOutcome
    @MainActor func continueInApp(_ request: UnblockRequest)
}

enum UnblockIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case openNormal
    case notAtLocation(LocationRadiusKind)
    case unblockFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .openNormal: "Open Normal to unblock."
        case .notAtLocation(.unblock): "You're outside your unblock radius."
        case .notAtLocation(.block): "You're inside your block radius."
        case .unblockFailed: "Couldn't start the unblock. Open Normal and try again."
        }
    }
}

struct UnblockAllIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock All Apps"
    static let description = IntentDescription(
        "Unblocks the apps and websites selected in Normal after checking your key. NFC Tag and QR Code / Barcode keys open Normal to scan. A Location key is checked without opening Normal when Background Location is on and a duration is set. With no Key Type or Unblock Duration, Normal uses your defaults."
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
        case .unblocked, .alreadyUnblocked:
            return .result(dialog: "").withoutDialog
        case .timedUnblockRunning:
            return .result(dialog: "A timed unblock is already running for all apps.")
        case let .continueInApp(reason):
            return try await continueInApp(
                request,
                reason: reason,
                performer: performer,
                fallback: OpenUnblockIntent(group: nil, keyType: keyType, duration: duration)
            )
        }
    }
}

struct UnblockGroupIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock Group"
    static let description = IntentDescription(
        "Unblocks one of your Normal groups after checking your key. NFC Tag and QR Code / Barcode keys open Normal to scan. A Location key is checked without opening Normal when Background Location is on and a duration is set. With no Key Type or Unblock Duration, Normal uses your defaults."
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
        case .unblocked, .alreadyUnblocked:
            return .result(dialog: "").withoutDialog
        case let .timedUnblockRunning(name):
            return .result(dialog: "A timed unblock is already running for \(name).")
        case let .continueInApp(reason):
            return try await continueInApp(
                request,
                reason: reason,
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
        reason: HandOffReason,
        performer: any UnblockIntentPerforming,
        fallback: OpenUnblockIntent
    ) async throws -> IntentResultContainer<Never, Never, Never, IntentDialog> {
        if #available(iOS 26.0, *) {
            if systemContext.currentMode == .background {
                guard systemContext.currentMode.canContinueInForeground else {
                    performer.continueInApp(request)
                    throw UnblockIntentError.openNormal
                }
                try await continueInForeground(IntentDialog(reason.prompt), alwaysConfirm: false)
            }
            performer.continueInApp(request)
            return .result(dialog: "").withoutDialog
        }
        if #available(iOS 18.2, *) {
            guard let notice = reason.notice else {
                return .result(opensIntent: fallback, dialog: "").withoutDialog
            }
            return .result(opensIntent: fallback, dialog: IntentDialog(notice))
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
