import Foundation

enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    case screenTimePermission
    case tabHome
    case tabAppSelect
    case tabKeys
    case tabGroups
    case tabSchedules
    case complete

    var requiredTab: AppTab? {
        switch self {
        case .tabHome: .home
        case .tabAppSelect: .appSelect
        case .tabKeys: .keys
        case .tabGroups: .groups
        case .tabSchedules: .schedules
        default: nil
        }
    }

    var isTabWalkthrough: Bool { requiredTab != nil }

    var title: String {
        switch self {
        case .tabHome: "Home"
        case .tabAppSelect: "App Select"
        case .tabKeys: "Keys"
        case .tabGroups: "Groups"
        case .tabSchedules: "Schedules"
        default: ""
        }
    }

    var description: String {
        switch self {
        case .tabHome: "View your block status and quickly block or unblock all your selected apps."
        case .tabAppSelect: "Choose which apps you want Normal to manage. These are the apps that can be blocked."
        case .tabKeys: "Register NFC tags or QR codes as physical keys to lock and unlock your apps."
        case .tabGroups: "Organize your apps into groups so you can block and unblock them separately."
        case .tabSchedules: "Set up automatic schedules to block apps at certain times and days."
        default: ""
        }
    }

    func next() -> OnboardingStep {
        guard let index = Self.allCases.firstIndex(of: self),
              index + 1 < Self.allCases.count
        else { return .complete }
        return Self.allCases[index + 1]
    }
}
