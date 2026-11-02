import SwiftUI

struct BlockStatusView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService

    let mainSelection: SelectedApps

    private var customDomains: [String] {
        mainSelection.customDomains
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
        SummaryRow(
            systemImage: status.icon,
            tint: status.color,
            title: Text(LocalizedStringKey(status.title)),
            subtitle: Text("\(screenTimeService.activeShieldCount()) of \(totalCount) Blocked")
        )
    }
}
