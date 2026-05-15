import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    let settings: Settings
    let availableKeyTypes: [KeyType]

    private static let defaultPageOptions: [AppTab] = [.home, .groups, .schedules]

    var body: some View {
        List {
            defaultPageSection
            appDeletionSection
            quickUnblockSection
        }
    }

    private var defaultPageSection: some View {
        Section {
            Picker(
                "Default Page",
                selection: Binding(
                    get: { settings.defaultTab ?? .home },
                    set: { settings.defaultTab = $0 }
                )
            ) {
                ForEach(Self.defaultPageOptions, id: \.self) { tab in
                    Text(tab.label).tag(tab)
                }
            }
        } header: {
            Text("Default Page")
        } footer: {
            Text("The page shown when the app opens.")
        }
    }

    private var appDeletionSection: some View {
        Section {
            Toggle(
                "Block All Prevents App Deletion",
                isOn: Bindable(settings).blockAllPreventsAppDelete
            )
        } header: {
            Text("App Deletion Protection")
        } footer: {
            Text("When enabled, blocking all apps also prevents app deletion, and unblocking re-allows it.")
        }
    }

    private var quickUnblockSection: some View {
        Section {
            Picker(
                "Default Key Type",
                selection: Binding(
                    get: {
                        guard let keyType = settings.defaultKeyType,
                              availableKeyTypes.contains(keyType)
                        else { return KeyType?.none }
                        return keyType
                    },
                    set: { settings.defaultKeyType = $0 }
                )
            ) {
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
