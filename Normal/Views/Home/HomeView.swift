import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]

    private var mainSelection: SelectedApps? { selectedApps.first }

    var body: some View {
        NavigationStack {
            List {
                if let mainSelection, !mainSelection.selection.isEmpty {
                    TimedUnblockBannerView(selection: mainSelection.selection)
                    MainBlockButtonView(mainSelection: mainSelection)
                    BlockStatusView(mainSelection: mainSelection)
                    AppDeleteToggleView()
                } else {
                    Section {
                        Text("Please select apps to block in the selection tab.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Home")
            .settingsToolbar()
        }
    }
}
