import SwiftData
import SwiftUI

struct BlockStatusView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]

    let mainSelection: SelectedApps

    private var customDomains: [String] {
        (allSettings.first?.enableCustomDomains ?? false) ? mainSelection.customDomains : []
    }

    private var status: BlockStatus {
        screenTimeService.blockStatus(selection: mainSelection.selection, customDomains: customDomains)
    }

    private var totalCount: Int {
        mainSelection.selection.count + customDomains.count
    }

    var body: some View {
        Section("Status") {
            NavigationLink {
                StatusDetailView(mainSelection: mainSelection)
            } label: {
                statusRow
            }
            .accessibilityIdentifier("home.statusLink")
        }
    }

    private var statusRow: some View {
        HStack(spacing: DS.Spacing.lg - 1) {
            Image(systemName: status.icon)
                .font(.title)
                .foregroundStyle(status.color)

            VStack(alignment: .leading) {
                Text(status.title)
                    .font(.headline)
                Text("\(screenTimeService.activeShieldCount()) of \(totalCount) Blocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
