import SwiftUI

enum LocationRadiusKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case unblock = "UNBLOCK"
    case block = "BLOCK"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unblock: "Location"
        case .block: "Block Radius"
        }
    }

    var shortLabel: String {
        switch self {
        case .unblock: "Unblock"
        case .block: "Block"
        }
    }

    var icon: String { "location.fill" }

    var zoneColor: Color {
        switch self {
        case .unblock: .green
        case .block: .red
        }
    }

    var fieldColor: Color {
        switch self {
        case .unblock: .red
        case .block: .green
        }
    }

    var zoneLegend: String {
        switch self {
        case .unblock: "Unblock radius"
        case .block: "Block radius"
        }
    }

    var fieldLegend: String {
        switch self {
        case .unblock: "Blocked elsewhere"
        case .block: "Can unblock elsewhere"
        }
    }

    var pickerFooter: String {
        switch self {
        case .unblock: "Your location key will only work while you're inside one of these areas. Set one up to unlock at the office, the gym, or anywhere you choose."
        case .block: "Your location key will only work while you're outside the selected areas. Set one up to lock yourself out at home, school, or anywhere you choose."
        }
    }
}
