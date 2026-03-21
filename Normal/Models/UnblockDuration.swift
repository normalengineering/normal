import Foundation

enum UnblockDuration: Int, CaseIterable, Identifiable, Sendable {
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .fifteenMinutes: "15 Minutes"
        case .thirtyMinutes: "30 Minutes"
        case .oneHour: "1 Hour"
        case .twoHours: "2 Hours"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}
