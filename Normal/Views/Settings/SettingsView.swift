import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]

    @State private var showConfirmation = false
    @State private var showSuccessAlert = false
    @State private var selectedTab: SettingsTab = .general

    private var settings: Settings { allSettings.unwrapped }

    private var availableKeyTypes: [KeyType] {
        KeyType.allCases.filter { type in keys.contains { $0.type == type } }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab(SettingsTab.general.title, systemImage: SettingsTab.general.icon, value: SettingsTab.general) {
                    GeneralSettingsView(
                        settings: settings,
                        availableKeyTypes: availableKeyTypes
                    )
                    .navigationTitle(SettingsTab.general.title)
                }

                Tab(SettingsTab.emergencyUnblock.title, systemImage: SettingsTab.emergencyUnblock.icon, value: SettingsTab.emergencyUnblock) {
                    EmergencyUnblockView(
                        settings: settings,
                        showConfirmation: $showConfirmation,
                        performEmergencyUnblock: performEmergencyUnblock
                    )
                    .navigationTitle("Emergency Unblock")
                }

                Tab(SettingsTab.faq.title, systemImage: SettingsTab.faq.icon, value: SettingsTab.faq) {
                    FAQView()
                        .navigationTitle("FAQ")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Emergency Unblock", isPresented: $showConfirmation) {
                Button("Unblock All Apps", role: .destructive, action: performEmergencyUnblock)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will immediately remove all app blocks. Each unblock regenerates after 6 months. You have \(settings.emergencyUnblocksAvailable) remaining.")
            }
            .alert("All Apps Unblocked", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("All app blocks have been removed. You have \(settings.emergencyUnblocksAvailable) emergency unblock\(settings.emergencyUnblocksAvailable == 1 ? "" : "s") remaining.")
            }
        }
    }

    private func performEmergencyUnblock() {
        settings.recordEmergencyUnblock()
        screenTimeService.removeShieldOnAll(allowAppDelete: true)
        showSuccessAlert = true
    }
}
