import Foundation
import SwiftData

enum IntentSurfaceSync {
    static func sync(
        context: ModelContext,
        settings: Settings,
        screenTimeService: any ScreenTimeProviding,
        timedUnblockService: TimedUnblockService
    ) {
        let groups = (try? context.fetch(FetchDescriptor<AppGroup>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let keys = (try? context.fetch(FetchDescriptor<Key>())) ?? []
        WidgetSync.sync(groups: groups, keys: keys, settings: settings, screenTimeService: screenTimeService)
        LiveActivityManager.reconcile(
            timedUnblockService: timedUnblockService,
            groups: groups,
            isEnabled: settings.showTimedUnblockLiveActivity
        )
    }
}
