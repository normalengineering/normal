import ActivityKit
import Foundation

struct LiveActivityPlan: Equatable {
    let toStart: [String]
    let toUpdate: [String]
    let toEnd: [String]

    init(activeIDs: Set<String>, runningIDs: Set<String>) {
        toStart = activeIDs.subtracting(runningIDs).sorted()
        toUpdate = activeIDs.intersection(runningIDs).sorted()
        toEnd = runningIDs.subtracting(activeIDs).sorted()
    }
}

enum LiveActivityManager {
    @MainActor
    static func reconcile(active: [String: Date], titles: [String: String]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let running = Activity<TimedUnblockActivityAttributes>.activities
        let runningByID = Dictionary(
            running.map { ($0.attributes.unblockID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = LiveActivityPlan(activeIDs: Set(active.keys), runningIDs: Set(runningByID.keys))

        for id in plan.toEnd {
            guard let activity = runningByID[id] else { continue }
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        for id in plan.toUpdate {
            guard let activity = runningByID[id], let endDate = active[id] else { continue }
            Task { await activity.update(content(endingAt: endDate)) }
        }

        for id in plan.toStart {
            guard let endDate = active[id] else { continue }
            let attributes = TimedUnblockActivityAttributes(
                title: titles[id] ?? String(localized: "Apps"),
                unblockID: id,
                startDate: .now
            )
            _ = try? Activity.request(attributes: attributes, content: content(endingAt: endDate))
        }
    }

    private static func content(
        endingAt endDate: Date
    ) -> ActivityContent<TimedUnblockActivityAttributes.ContentState> {
        ActivityContent(
            state: .init(endDate: endDate),
            staleDate: endDate,
            relevanceScore: -endDate.timeIntervalSinceReferenceDate
        )
    }
}
