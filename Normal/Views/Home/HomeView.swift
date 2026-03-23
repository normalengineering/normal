import SwiftData
import SwiftUI

struct HomeView: View {
    @Query private var selectedApps: [SelectedApps]
    @Query private var keys: [Key]
    @State private var showSettings = false

    private var mainSelection: SelectedApps? { selectedApps.first }

    var body: some View {
        NavigationStack {
            List {
                if let mainSelection,
                   !isSelectionEmpty(selection: mainSelection.selection)
                {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}
