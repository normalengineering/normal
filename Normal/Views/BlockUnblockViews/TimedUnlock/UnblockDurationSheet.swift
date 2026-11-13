import SwiftData
import SwiftUI

struct UnblockDurationSheet: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]

    let target: UnblockTarget
    var onUnblock: () -> Void = {}

    private var settings: Settings {
        allSettings.unwrapped
    }

    private var title: String {
        switch target {
        case .all: "Unblock All"
        case let .group(group): "Unblock \(group.name)"
        }
    }

    var body: some View {
        TimedUnblockSheet(
            title: title,
            durations: settings.unblockDurations,
            initialDuration: settings.defaultDuration,
            onTimedUnblock: { duration in
                try timedUnblockService.start(
                    target,
                    duration: duration,
                    settings: settings,
                    screenTimeService: screenTimeService
                )
                onUnblock()
            },
            onPermanentUnblock: {
                screenTimeService.unblockPermanently(target, settings: settings)
                onUnblock()
            }
        )
    }
}
