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
    static func reconcile(timedUnblockService: TimedUnblockService, groups: [AppGroup], isEnabled: Bool) {
        var titles = [TimedUnblockService.mainID: String(localized: "All Apps")]
        for group in groups {
            titles[group.id.uuidString] = group.name
        }
        reconcile(
            active: isEnabled ? timedUnblockService.activeUnblocks : [:],
            titles: titles,
            startDates: timedUnblockService.activeUnblockStartDates()
        )
    }

    @MainActor
    static func reconcile(active: [String: Date], titles: [String: String], startDates: [String: Date] = [:]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let all = Activity<TimedUnblockActivityAttributes>.activities
        for activity in all where !isRunning(activity.activityState) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        let running = all.filter { isRunning($0.activityState) }
        var runningByID: [String: Activity<TimedUnblockActivityAttributes>] = [:]
        for activity in running {
            let id = activity.attributes.unblockID
            if let existing = runningByID[id] {
                let desiredTitle = titles[id]
                if existing.attributes.title != desiredTitle, activity.attributes.title == desiredTitle {
                    runningByID[id] = activity
                    Task { await existing.end(nil, dismissalPolicy: .immediate) }
                } else {
                    Task { await activity.end(nil, dismissalPolicy: .immediate) }
                }
            } else {
                runningByID[id] = activity
            }
        }
        let plan = LiveActivityPlan(activeIDs: Set(active.keys), runningIDs: Set(runningByID.keys))

        for id in plan.toEnd {
            guard let activity = runningByID[id] else { continue }
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        for id in plan.toUpdate {
            guard let activity = runningByID[id], let endDate = active[id] else { continue }
            let desiredTitle = titles[id] ?? String(localized: "Apps")
            if activity.attributes.title != desiredTitle {
                let attributes = TimedUnblockActivityAttributes(
                    title: desiredTitle,
                    unblockID: id,
                    startDate: startDates[id] ?? activity.attributes.startDate
                )
                let newContent = content(endingAt: endDate)
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    _ = try? Activity.request(attributes: attributes, content: newContent)
                }
            } else {
                Task { await activity.update(content(endingAt: endDate)) }
            }
        }

        for id in plan.toStart {
            guard let endDate = active[id] else { continue }
            let attributes = TimedUnblockActivityAttributes(
                title: titles[id] ?? String(localized: "Apps"),
                unblockID: id,
                startDate: startDates[id] ?? .now
            )
            _ = try? Activity.request(attributes: attributes, content: content(endingAt: endDate))
        }
    }

    static func isRunning(_ state: ActivityState) -> Bool {
        switch state {
        case .ended, .dismissed:
            false
        default:
            true
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
