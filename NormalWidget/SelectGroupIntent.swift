import AppIntents
import WidgetKit

struct SelectGroupIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Unlock"
    static let description = IntentDescription("Choose a group to unlock via the Home Screen.")

    @Parameter(title: "Group")
    var group: GroupEntity?

    @Parameter(title: "Unblock Duration")
    var unblockDuration: UnblockDurationEntity?

    @Parameter(title: "Legacy Duration")
    var duration: UnblockDuration?

    @Parameter(title: "Key Type")
    var keyType: KeyTypeEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Unlock \(\.$group)") {
            \.$unblockDuration
            \.$keyType
        }
    }

    var durationRequest: UnlockDurationRequest {
        if let unblockDuration {
            return unblockDuration.request
        }
        return duration
            .flatMap { TimedUnblockDuration(validating: $0.rawValue) }
            .map(UnlockDurationRequest.fixed) ?? .useDefault
    }
}
