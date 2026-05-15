import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    let settings: Settings
    let availableKeyTypes: [KeyType]

    var body: some View {
        List {
            Section {
                Picker("Default Page", selection: Binding(
                    get: { settings.defaultTab ?? .home },
                    set: { settings.defaultTab = $0 }
                )) {
                    Text(AppTab.home.label).tag(AppTab.home)
                    Text(AppTab.groups.label).tag(AppTab.groups)
                    Text(AppTab.schedules.label).tag(AppTab.schedules)
                }
            } header: {
                Text("Default Page")
            } footer: {
                Text("The page shown when the app opens.")
            }

            Section {
                Toggle("Block All Prevents App Deletion", isOn: Bindable(settings).blockAllPreventsAppDelete)
            } header: {
                Text("App Deletion Protection")
            } footer: {
                Text("When enabled, blocking all apps also prevents app deletion, and unblocking re-allows it.")
            }

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
                Text("Quick Unblock Settings")
            } footer: {
                Text("When set, unblocking skips the key type and duration selection steps.")
            }
        }
    }
}