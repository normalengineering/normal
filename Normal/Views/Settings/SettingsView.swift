import SwiftData
import SwiftUI

enum SettingsTab: CaseIterable {
    case general
    case emergencyUnblock
    case faq

    var title: String {
        switch self {
        case .general:
            return "General"
        case .emergencyUnblock:
            return "Emergency"
        case .faq:
            return "FAQ"
        }
    }

    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .emergencyUnblock:
            return "exclamationmark.triangle"
        case .faq:
            return "questionmark.circle"
        }
    }
}

struct SettingsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]

    @State private var showConfirmation = false
    @State private var selectedTab: SettingsTab = .general

    private var settings: Settings { allSettings.first! }

    private var availableKeyTypes: [KeyType] {
        KeyType.allCases.filter { type in
            keys.contains { $0.type == type }
        }
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                Tab("General", systemImage: "gear", value: SettingsTab.general) {
                    GeneralSettingsView(
                        settings: settings,
                        availableKeyTypes: availableKeyTypes
                    )
                    .navigationTitle("General")
                }

                Tab("Emergency", systemImage: "exclamationmark.triangle", value: SettingsTab.emergencyUnblock) {
                    EmergencyUnblockView(
                        settings: settings,
                        showConfirmation: $showConfirmation,
                        performEmergencyUnblock: performEmergencyUnblock
                    )
                    .navigationTitle("Emergency Unblock")
                }

                Tab("FAQ", systemImage: "questionmark.circle", value: SettingsTab.faq) {
                    FAQView()
                        .navigationTitle("FAQ")
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert(
                "Emergency Unblock",
                isPresented: $showConfirmation
            ) {
                Button("Unblock All Apps", role: .destructive) {
                    performEmergencyUnblock()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will immediately remove all app blocks. Each unblock regenerates after 6 months. You have \(settings.emergencyUnblocksAvailable) remaining.")
            }
        }
    }

    private func performEmergencyUnblock() {
        settings.recordEmergencyUnblock()
        screenTimeService.removeShieldOnAll(allowAppDelete: true)
    }
}
