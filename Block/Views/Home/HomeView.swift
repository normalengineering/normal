import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var selectedApps: [SelectedApps]

    private var master: SelectedApps? {
        selectedApps.first
    }

    private var hasSelection: Bool {
        guard let selection = master?.selection else { return false }
        return !selection.applicationTokens.isEmpty ||
            !selection.categoryTokens.isEmpty ||
            !selection.webDomainTokens.isEmpty
    }

    var body: some View {
        VStack {
            if hasSelection, let master {
                Button(action: buttonToggle) {
                    Label(master.isBlocked ? "Unblock" : "Block", systemImage: master.isBlocked ? "lock.open.fill" : "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(master.isBlocked ? .red : .blue)
                .padding()

            } else {
                Text("Please select apps to block.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    func buttonToggle() {
        master!.toggleBlockedStatus()

        if master!.isBlocked {
            screenTimeService.applyShieldOnAll(selection: master!.selection)
        } else {
            screenTimeService.removeShieldOnAll()
        }
    }
}
