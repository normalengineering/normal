import ActivityKit
import Foundation

struct TimedUnblockActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var title: String
    var unblockID: String
    var startDate: Date
}
