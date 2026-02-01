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
                        let blockStatus = screenTimeService.blockStatus(selection: mainSelection.selection)
                        if blockStatus != .all {
                            Button(action: { screenTimeService.applyShieldOnAll(selection: mainSelection.selection) }) {
                                HStack {
                                    Label("Block All",
                                          systemImage: "lock.fill")
                                        .foregroundStyle(.blue)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        if blockStatus != .none {
                            Button(action: { screenTimeService.removeShieldOnAll() }) {
                                HStack {
                                    Label("Unblock All",
                                          systemImage: "lock.open.fill")
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    Section("Status") {
                        BlockStatusView(mainSelection: mainSelection)
                    }

                    Section(header: Text("Configuration"), footer: Text("Strict mode prevents app deletion when activated.")) {
                        Toggle("Strict Mode", isOn: $strictModeToggle)
                            .tint(.accentColor)
                            .onChange(of: strictModeToggle) { _, newValue in
                                if newValue == true {
                                    screenTimeService.enableStrictMode()
                                } else {
                                    screenTimeService.disableStrictMode()
                                }
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
                strictModeToggle = screenTimeService.isStrictModeEnabled
            }
        }
    }
}
