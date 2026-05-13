import Foundation

enum AppTab: String, CaseIterable, Codable {
    case home
    case groups
    case schedules
    case appSelect
    case keys

    var label: String {
        switch self {
        case .home: "Home"
        case .groups: "Groups"
        case .schedules: "Schedules"
        case .appSelect: "App Select"
        case .keys: "Keys"
        }
    }
}
