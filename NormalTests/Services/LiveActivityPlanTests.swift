@testable import Normal
import Testing

struct LiveActivityPlanTests {
    @Test func startsActivitiesForNewlyActiveUnblocks() {
        let plan = LiveActivityPlan(activeIDs: ["main", "g1"], runningIDs: [])
        #expect(plan.toStart == ["g1", "main"])
        #expect(plan.toUpdate.isEmpty)
        #expect(plan.toEnd.isEmpty)
    }

    @Test func endsActivitiesForUnblocksNoLongerActive() {
        let plan = LiveActivityPlan(activeIDs: [], runningIDs: ["main", "g1"])
        #expect(plan.toStart.isEmpty)
        #expect(plan.toEnd == ["g1", "main"])
    }

    @Test func updatesActivitiesThatRemainActive() {
        let plan = LiveActivityPlan(activeIDs: ["g1"], runningIDs: ["g1"])
        #expect(plan.toUpdate == ["g1"])
        #expect(plan.toStart.isEmpty)
        #expect(plan.toEnd.isEmpty)
    }

    @Test func mixedStartUpdateEnd() {
        let plan = LiveActivityPlan(activeIDs: ["main", "g2"], runningIDs: ["main", "g1"])
        #expect(plan.toStart == ["g2"]) // newly active
        #expect(plan.toUpdate == ["main"]) // still active
        #expect(plan.toEnd == ["g1"]) // expired/cancelled
    }

    @Test func secondGroupStartsWhileFirstKeepsRunning() {
        let plan = LiveActivityPlan(activeIDs: ["g1", "g2"], runningIDs: ["g1"])
        #expect(plan.toStart == ["g2"])
        #expect(plan.toUpdate == ["g1"])
        #expect(plan.toEnd.isEmpty)
    }

    @Test func cancellingOneOfTwoGroupsEndsOnlyThatActivity() {
        let plan = LiveActivityPlan(activeIDs: ["g2"], runningIDs: ["g1", "g2"])
        #expect(plan.toEnd == ["g1"])
        #expect(plan.toUpdate == ["g2"])
        #expect(plan.toStart.isEmpty)
    }

    @Test func emptyOnBothSidesIsNoOp() {
        let plan = LiveActivityPlan(activeIDs: [], runningIDs: [])
        #expect(plan.toStart.isEmpty && plan.toUpdate.isEmpty && plan.toEnd.isEmpty)
    }
}
