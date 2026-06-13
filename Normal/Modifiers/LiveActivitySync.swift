import SwiftData
import SwiftUI

private struct LiveActivitySyncModifier: ViewModifier {
    @Environment(TimedUnblockService.self) private var timedUnblockService
    @Query(sort: [SortDescriptor(\AppGroup.sortIndex)]) private var groups: [AppGroup]

    func body(content: Content) -> some View {
        content
            .onChange(of: timedUnblockService.activeUnblocks) { _, _ in reconcile() }
            .onAppear { reconcile() }
    }

    private func reconcile() {
        var titles = [TimedUnblockService.mainID: String(localized: "All Apps")]
        for group in groups {
            titles[group.id.uuidString] = group.name
        }
        LiveActivityManager.reconcile(active: timedUnblockService.activeUnblocks, titles: titles)
    }
}

extension View {
    func liveActivitySync() -> some View {
        modifier(LiveActivitySyncModifier())
    }
}
