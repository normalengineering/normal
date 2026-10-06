import ActivityKit
import Foundation

nonisolated struct TimedUnblockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var title: String
    var unblockID: String
    var startDate: Date
}
