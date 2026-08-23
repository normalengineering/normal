import SwiftUI

extension UsageLimitState {
    var label: LocalizedStringKey {
        switch self {
        case .under: "Available"
        case .warning: "Almost Reached"
        case .reached: "Limit Reached"
        }
    }

    var icon: String {
        switch self {
        case .under: "hourglass"
        case .warning: "hourglass.bottomhalf.filled"
        case .reached: "lock.fill"
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
