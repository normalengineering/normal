import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case emergencyUnblock
    case faq
    case donation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .emergencyUnblock: "Emergency"
        case .faq: "FAQ"
        case .donation: "Donate"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .emergencyUnblock: "exclamationmark.triangle"
        case .faq: "questionmark.circle"
        case .donation: "heart.fill"
        }
    }
}
