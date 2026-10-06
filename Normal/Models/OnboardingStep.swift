import Foundation

enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    case screenTimePermission
    case tabHome
    case tabAppSelect
    case tabKeys
    case tabGroups
    case tabSchedules
    case finish
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

    var isTabWalkthrough: Bool {
        requiredTab != nil
    }

    var title: LocalizedStringResource? {
        switch self {
        case .tabHome: return "Home"
        case .tabAppSelect: return "App Select"
        case .tabKeys: return "Keys"
        case .tabGroups: return "Groups"
        case .tabSchedules: return "Schedules"
        default: return nil
        }
    }

    var description: LocalizedStringResource? {
        switch self {
        case .tabHome: return "View your block status and quickly block or unblock all your selected apps."
        case .tabAppSelect: return "Choose which apps you want Normal to manage. These are the apps that can be blocked."
        case .tabKeys: return "Add keys to lock and unlock your apps. A key can be an NFC tag, a QR code/barcode, or a location."
        case .tabGroups: return "Organize your apps into groups so you can block and unblock them independently."
        case .tabSchedules: return "Set up automatic schedules to block apps at certain times and days."
        default: return nil
        }
    }

    func next() -> OnboardingStep {
        guard let index = Self.allCases.firstIndex(of: self),
              index + 1 < Self.allCases.count
        else { return .complete }
        return Self.allCases[index + 1]
    }
}
