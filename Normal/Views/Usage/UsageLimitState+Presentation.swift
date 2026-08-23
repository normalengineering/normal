import SwiftUI

/// Presentation for the three states a limit can be in today. Mirrors
/// `BlockStatus` so usage rows and block rows read the same way.
extension UsageLimitState {
    var shortLabel: String {
        switch self {
        case .under: String(localized: "Available")
        case .warning: String(localized: "Almost Up")
        case .reached: String(localized: "Used Up")
        }
    }

    var icon: String {
        switch self {
        case .under: "hourglass"
        case .warning: "hourglass.bottomhalf.filled"
        case .reached: "hourglass.tophalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .under: .green
        case .warning: .orange
        case .reached: .red
        }
    }
}
