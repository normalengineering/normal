import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case emergencyUnblock
    case faq

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .emergencyUnblock: "Emergency"
        case .faq: "FAQ"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .emergencyUnblock: "exclamationmark.triangle"
        case .faq: "questionmark.circle"
        }
    }
}
