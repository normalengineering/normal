import ActivityKit
import AppIntents

struct DismissUnblockActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Dismiss block reminder"
    static var openAppWhenRun: Bool { false }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Unblock ID")
    var unblockID: String

    init() {}

    init(unblockID: String) {
        self.unblockID = unblockID
    }

    func perform() async throws -> some IntentResult {
        await Self.dismiss(unblockID: unblockID)
        return .result()
    }

    @MainActor
    private static func dismiss(unblockID: String) async {
        for activity in Activity<TimedUnblockActivityAttributes>.activities
            where activity.attributes.unblockID == unblockID
        {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
