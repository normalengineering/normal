import FamilyControls
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var selectedApps: [SelectedApps]
    @State private var strictModeToggle = false

    private var master: SelectedApps? { selectedApps.first }

    private var hasSelection: Bool {
        guard let selection = master?.selection else { return false }
        return !selection.applicationTokens.isEmpty ||
               !selection.categoryTokens.isEmpty ||
               !selection.webDomainTokens.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if let master = master, hasSelection {
                    Section {
                        Button(action: buttonToggle) {
                            HStack {
                                Label(master.isBlocked ? "Unblock All" : "Activate Block",
                                      systemImage: master.isBlocked ? "lock.open.fill" : "lock.fill")
                                    .foregroundStyle(master.isBlocked ? .red : .blue)
                                Spacer()
                            }
                        }
                    }

                    Section(header: Text("Configuration"), footer: Text("Strict mode prevents app deletion and modification while active.")) {
                        Toggle("Strict Mode", isOn: $strictModeToggle)
                            .tint(.accentColor)
                            .onChange(of: strictModeToggle) { _, newValue in
                                master.strictMode = newValue
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
                if let master = master {
                    strictModeToggle = master.strictMode
                }
            }
        }
    }

    func buttonToggle() {
        guard let master = master else { return }
        withAnimation(.spring) {
            master.toggleBlockedStatus()
        }

        if master.isBlocked {
            screenTimeService.applyShieldOnAll(selection: master.selection)
            if master.strictMode {
                screenTimeService.enableStrictMode()
            }
        } else {
            screenTimeService.removeShieldOnAll()
        }
    }
}
