import SwiftData
import SwiftUI

struct GroupTimedUnblockSheet: View {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]

    let group: AppGroup

    private var customDomains: [String] {
        (allSettings.first?.enableCustomDomains ?? false) ? group.customDomains : []
    }

    var body: some View {
        TimedUnblockSheet(
            title: "Unblock \(group.name)",
            onTimedUnblock: { duration in
                try timedUnblockService.startGroup(
                    duration: duration,
                    groupId: group.id,
                    selection: group.selection,
                    customDomains: customDomains,
                    screenTimeService: screenTimeService
                )
            },
            onPermanentUnblock: {
                screenTimeService.removeFromShields(selection: group.selection, customDomains: customDomains)
            }
        )
    }
}
