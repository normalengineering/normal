import SwiftData
import SwiftUI

struct UnblockDurationSheet: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]

    let grant: UnblockGrant
    var onUnblock: () -> Void = {}

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var title: String {
        switch grant.target {
        case .all: "Unblock All"
        case let .group(group): "Unblock \(group.name)"
        }
    }

    var body: some View {
        TimedUnblockSheet(
            title: title,
            durations: settings.unblockDurations,
            initialDuration: settings.defaultDuration,
            onConfirm: { length in
                try BlockActions.unblock(
                    grant,
                    for: length,
                    settings: settings,
                    screenTimeService: screenTimeService,
                    timedUnblockService: timedUnblockService
                )
                onUnblock()
            }
        )
    }
}
