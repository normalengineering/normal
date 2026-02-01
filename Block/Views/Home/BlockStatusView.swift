import SwiftUI

extension BlockStatus {
    var title: String {
        switch self {
        case .all: return "All Selected Apps Blocked"
        case .some: return "Partially Blocked"
        case .none: return "No Active Blocks"
        }
    }

    var color: Color {
        switch self {
        case .all: return .green
        case .some: return .orange
        case .none: return .red
        }
    }

    var icon: String {
        switch self {
        case .all: return "checkmark.shield.fill"
        case .some: return "exclamationmark.shield.fill"
        case .none: return "shield.slash"
        }
    }
}

struct BlockStatusView: View {
    let mainSelection: SelectedApps

    @Environment(ScreenTimeService.self) private var screenTimeService

    private var currentStatus: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection)
    }

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: currentStatus.icon)
                .font(.title)
                .foregroundStyle(currentStatus.color)

            VStack(alignment: .leading) {
                Text(currentStatus.title)
                    .font(.headline)
                Text("\(screenTimeService.activeShieldCount()) of \(selectionCount(selection: mainSelection.selection)) Blocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
