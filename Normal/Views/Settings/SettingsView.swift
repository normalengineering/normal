import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Query private var allSettings: [Settings]
    @Query private var keys: [Key]

    @State private var showConfirmation = false

    private var settings: Settings { allSettings.first! }

    private var availableKeyTypes: [KeyType] {
        KeyType.allCases.filter { type in
            keys.contains { $0.type == type }
        }
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Default Key Type", selection: Binding(
                        get: {
                            guard let keyType = settings.defaultKeyType,
                                  availableKeyTypes.contains(keyType) else { return KeyType?.none }
                            return keyType
                        },
                        set: { settings.defaultKeyType = $0 }
                    )) {
                        Text("None").tag(KeyType?.none)
                        ForEach(availableKeyTypes) { type in
                            Label(type.label, systemImage: type.icon).tag(KeyType?.some(type))
                        }
                    }

                    Picker("Default Unblock Duration", selection: Bindable(settings).defaultUnblockDuration) {
                        Text("None").tag(UnblockDuration?.none)
                        ForEach(UnblockDuration.allCases) { duration in
                            Text(duration.label).tag(UnblockDuration?.some(duration))
                        }
                    }
                } header: {
                    Text("Unblock Defaults")
                } footer: {
                    Text("When set, unblocking skips the key type and duration selection steps.")
                }

                Section {
                    Text("\(settings.emergencyUnblocksAvailable) of \(Settings.maxEmergencyUnblocks) remaining")

                    Button("Emergency Unblock") {
                        showConfirmation = true
                    }
                    .disabled(settings.emergencyUnblocksAvailable == 0)
                } header: {
                    Text("Emergency Unblock")
                } footer: {
                    Text("Immediately remove all blocks. Each use regenerates after 6 months.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .confirmationDialog(
                "Emergency Unblock",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Unblock All Apps", role: .destructive) {
                    performEmergencyUnblock()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will immediately remove all app blocks. You have \(settings.emergencyUnblocksAvailable) emergency unblock\(settings.emergencyUnblocksAvailable == 1 ? "" : "s") remaining.")
            }
        }
    }

    private func performEmergencyUnblock() {
        settings.recordEmergencyUnblock()
        screenTimeService.removeShieldOnAll()
        screenTimeService.disablePreventAppDelete()
    }
}
