import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var selectedApps: [SelectedApps]
    @State private var strictModeToggle = false

    private var mainSelection: SelectedApps? { selectedApps.first }

    var body: some View {
        NavigationStack {
            List {
                if let mainSelection = mainSelection, !isSelectionEmpty(selection: mainSelection.selection) {
                    Section {
                        Button(action: buttonToggle) {
                            HStack {
                                Label(mainSelection.isBlocked ? "Unblock All" : "Block All",
                                      systemImage: mainSelection.isBlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundStyle(mainSelection.isBlocked ? .red : .blue)
                                Spacer()
                            }
                        }
                    }

                    Section(header: Text("Configuration"), footer: Text("Strict mode prevents app deletion and modification while active.")) {
                        Toggle("Strict Mode", isOn: $strictModeToggle)
                            .tint(.accentColor)
                            .onChange(of: strictModeToggle) { _, newValue in
                                mainSelection.strictMode = newValue
                            }
                    }
                } else {
                    Section {
                        Text("Please select apps to block in the selection tab.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Home")
            .onAppear {
                if let mainSelection = mainSelection {
                    strictModeToggle = mainSelection.strictMode
                }
            }
        }
    }

    func buttonToggle() {
        guard let mainSelection = mainSelection else { return }
        withAnimation(.spring) {
            mainSelection.toggleBlockedStatus()
        }

        if mainSelection.isBlocked {
            screenTimeService.applyShieldOnAll(selection: mainSelection.selection)
            if mainSelection.strictMode {
                screenTimeService.enableStrictMode()
            }
        } else {
            screenTimeService.removeShieldOnAll()
        }
    }
}
