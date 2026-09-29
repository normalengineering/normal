import AppIntents
import Foundation

struct BlockOutcome: Sendable, Equatable {
    let name: String
    let wasAlreadyBlocked: Bool
}

protocol BlockIntentPerforming: Sendable {
    @MainActor func blockAll() throws -> BlockOutcome
    @MainActor func blockGroup(id: UUID) throws -> BlockOutcome
}

enum BlockIntentError: Error, Equatable, CustomLocalizedStringResourceConvertible {
    case setupIncomplete
    case screenTimeNotAuthorized
    case noGlobalKey
    case noAppsSelected
    case groupNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .setupIncomplete: "Finish setting up Normal first."
        case .screenTimeNotAuthorized: "Normal needs Screen Time access. Open Normal to allow it."
        case .noGlobalKey: "Add a key in Normal before blocking apps."
        case .noAppsSelected: "Select apps to block in Normal first."
        case .groupNotFound: "That group no longer exists."
        }
    }
}

struct BlockAllIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Block All Apps"
    static let description = IntentDescription(
        "Blocks the apps and websites selected in Normal. Unblocking still requires your key."
    )

    @Dependency private var performer: any BlockIntentPerforming

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try await performer.blockAll()
        return .result(
            dialog: outcome.wasAlreadyBlocked
                ? "All selected apps are already blocked."
                : "Blocked all selected apps."
        )
    }
}

struct BlockGroupIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Block Group"
    static let description = IntentDescription(
        "Blocks the apps in one of your Normal groups. Unblocking still requires your key."
    )

    @Parameter(title: "Group", requestValueDialog: "Which group should Normal block?")
    var group: GroupEntity

    @Dependency private var performer: any BlockIntentPerforming

    static var parameterSummary: some ParameterSummary {
        Summary("Block \(\.$group)")
    }

    init() {}

    init(group: GroupEntity?) {
        if let group { self.group = group }
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = try await performer.blockGroup(id: group.id)
        return .result(
            dialog: outcome.wasAlreadyBlocked
                ? "\(outcome.name) is already blocked."
                : "Blocked \(outcome.name)."
        )
    }
}
