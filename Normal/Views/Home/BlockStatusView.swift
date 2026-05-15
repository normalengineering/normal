import SwiftUI

struct BlockStatusView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    let mainSelection: SelectedApps

    private var status: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection)
    }

    var body: some View {
        Section("Status") {
            HStack(spacing: DS.Spacing.lg - 1) {
                Image(systemName: status.icon)
                    .font(.title)
                    .foregroundStyle(status.color)

                VStack(alignment: .leading) {
                    Text(status.title)
                        .font(.headline)
                    Text("\(screenTimeService.activeShieldCount()) of \(mainSelection.selection.count) Blocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
