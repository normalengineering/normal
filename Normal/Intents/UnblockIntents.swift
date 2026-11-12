import AppIntents
import Foundation

nonisolated struct UnblockRequest: Equatable, Sendable {
    let groupID: UUID?
    let duration: UnlockDurationRequest
    let keyType: KeyType?
}

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
    case unblocked(name: String, duration: TimedUnblockDuration)
    case alreadyUnblocked(name: String)
    case continueInApp
}

protocol UnblockIntentPerforming: Sendable {
    @MainActor func unblock(_ request: UnblockRequest) async throws -> UnblockOutcome
    @MainActor func continueInApp(_ request: UnblockRequest)
}

enum UnblockIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case notAtUnlockLocation
    case openNormal

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notAtUnlockLocation: "Your current location doesn't satisfy any of your location keys."
        case .openNormal: "Open Normal to unblock with this key."
        }
    }
}

struct UnblockAllIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock All Apps"
    static let description = IntentDescription(
        "Unblocks the apps and websites selected in Normal for a set time after checking your key. Location keys can be checked without opening Normal."
    )

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDurationEntity?

    @Dependency private var performer: any UnblockIntentPerforming

    static var parameterSummary: some ParameterSummary {
        Summary("Unblock all apps with \(\.$keyType)") {
            \.$duration
        }
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let request = UnblockRequest(group: nil, keyType: keyType, duration: duration)
        switch try await performer.unblock(request) {
        case let .unblocked(_, duration):
            return .result(dialog: "Unblocked all selected apps for \(duration.label).")
        case .alreadyUnblocked:
            return .result(dialog: "All selected apps are already unblocked.")
        case .continueInApp:
            return try OpenUnblockIntent(group: nil, keyType: keyType, duration: duration).handOff()
        }
    }
}

struct UnblockGroupIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unblock Group"
    static let description = IntentDescription(
        "Unblocks the apps in one of your Normal groups for a set time after checking your key. Location keys can be checked without opening Normal."
    )

    @Parameter(title: "Group", requestValueDialog: "Which group should Normal unblock?")
    var group: GroupEntity

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    @Parameter(title: "Unblock Duration")
    var duration: UnblockDurationEntity?

    @Dependency private var performer: any UnblockIntentPerforming

    static var parameterSummary: some ParameterSummary {
        Summary("Unblock \(\.$group) with \(\.$keyType)") {
            \.$duration
        }
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let request = UnblockRequest(group: group, keyType: keyType, duration: duration)
        switch try await performer.unblock(request) {
        case let .unblocked(name, duration):
            return .result(dialog: "Unblocked \(name) for \(duration.label).")
        case let .alreadyUnblocked(name):
            return .result(dialog: "\(name) is already unblocked.")
        case .continueInApp:
            return try OpenUnblockIntent(group: group, keyType: keyType, duration: duration).handOff()
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

    func handOff() throws -> IntentResultContainer<Never, Never, Never, IntentDialog> {
        guard #available(iOS 18.2, *) else { throw UnblockIntentError.openNormal }
        return .result(opensIntent: self, dialog: "Opening Normal to check your key.")
    }
}
