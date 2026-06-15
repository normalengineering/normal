import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    let settings: Settings
    let availableKeyTypes: [KeyType]

    private static let defaultPageOptions: [AppTab] = [.home, .groups, .schedules]
    private static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6768861415?action=write-review")!

    var body: some View {
        List {
            unblockingSection
            blockingSection
            appearanceSection
            aboutSection
        }
    }

    // MARK: - Unblocking

    private var unblockingSection: some View {
        Section {
            Picker(
                "Default Key",
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

            Picker("Default Duration", selection: Bindable(settings).defaultUnblockDuration) {
                Text("None").tag(UnblockDuration?.none)
                ForEach(UnblockDuration.allCases) { duration in
                    Text(duration.label).tag(UnblockDuration?.some(duration))
                }
            }

            Toggle(
                "Live Activity",
                isOn: Bindable(settings).showTimedUnblockLiveActivity
            )
        } header: {
            Text("Unblocking")
        } footer: {
            Text("A default key and duration skip those steps when unblocking. The Live Activity shows a Lock Screen and Dynamic Island countdown while a timed unblock runs.")
        }
    }

    // MARK: - Blocking

    private var blockingSection: some View {
        Section {
            Toggle(
                "Prevent App Deletion on Block All",
                isOn: Bindable(settings).blockAllPreventsAppDelete
            )
        } header: {
            Text("Blocking All Apps")
        } footer: {
            Text("When enabled Block All and app deletion are linked. Blocking all apps will prevent app deletion. Unblocking all re-allows deletion.")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
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

            Toggle(
                "Hide Donate Button",
                isOn: Bindable(settings).hideDonateButton
            )
        } header: {
            Text("Navigation & Appearance")
        } footer: {
            Text("Default Page opens when you launch the app. Hiding the Donate button removes it from the toolbar, you can still donate from the Donate tab.")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            Link(destination: Self.writeReviewURL) {
                Label("Rate Normal", systemImage: "star.fill")
            }
        } footer: {
            Text("If Normal has helped you, please consider leaving a review.")
        }
    }
}
