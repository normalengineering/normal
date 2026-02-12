import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var selectedApps: [SelectedApps]
    private var mainSelection: SelectedApps? { selectedApps.first }

    var body: some View {
        NavigationStack {
            List {
                if let mainSelection = mainSelection, !isSelectionEmpty(selection: mainSelection.selection) {
                    MainBlockButtonView(mainSelection: mainSelection)

                    BlockStatusView(mainSelection: mainSelection)

                    StrictModeToggleView()

                } else {
                    Section {
                        Text("Please select apps to block in the selection tab.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Home")
        }
    }
}
