import SwiftData
import SwiftUI

struct MainTimedUnblockSheet: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]

    let mainSelection: SelectedApps
    var onUnblock: () -> Void = {}

    private var settings: Settings {
        allSettings.unwrapped
    }

    var body: some View {
        TimedUnblockSheet(
            title: "Unblock All",
            durations: settings.unblockDurations,
            initialDuration: settings.defaultDuration,
            onTimedUnblock: { duration in
                try timedUnblockService.startMain(
                    duration: duration,
                    mainSelection: mainSelection,
                    settings: settings,
                    screenTimeService: screenTimeService
                )
                onUnblock()
            },
            onPermanentUnblock: {
                screenTimeService.unblockAll(
                    blockAllPreventsAppDelete: settings.blockAllPreventsAppDelete
                )
                onUnblock()
            }
        )
    }
}
