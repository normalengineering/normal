import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case emergencyUnblock
    case faq
    case contact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .emergencyUnblock: "Emergency"
        case .faq: "FAQ"
        case .contact: "Contact"
        }
    }

    var icon: String {
        switch self {
        case .general: "gear"
        case .emergencyUnblock: "exclamationmark.triangle"
        case .faq: "questionmark.circle"
        case .contact: "envelope"
        }
    }
}
