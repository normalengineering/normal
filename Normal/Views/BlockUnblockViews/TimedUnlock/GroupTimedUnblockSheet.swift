import SwiftUI

struct GroupTimedUnblockSheet: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService

    let group: AppGroup

    var body: some View {
        TimedUnblockSheet(
            title: "Unblock \(group.name)",
            onTimedUnblock: { duration in
                try timedUnblockService.startGroup(
                    duration: duration,
                    groupId: group.id,
                    selection: group.selection,
                    screenTimeService: screenTimeService
                )
            },
            onPermanentUnblock: {
                screenTimeService.removeFromShields(selection: group.selection)
            }
        )
    }
}
