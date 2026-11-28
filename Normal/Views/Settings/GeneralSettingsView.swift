import SwiftData
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Query private var keys: [Key]
    let settings: Settings
    let availableKeyTypes: [KeyType]

    @State private var customDomainsAuthAction: ProtectedAction?

    private static let defaultPageOptions: [AppTab] = [.home, .groups, .schedules]
    private static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6768861415?action=write-review")!

    var body: some View {
        List {
            blockingSection
            unblockingSection
            websitesSection
            appearanceSection
            aboutSection
            #if DEBUG
                Section("Debug") {
                    NavigationLink("Callback Log") { CallbackLogView() }
                }
            #endif
        }
        .keySelect(
            action: $customDomainsAuthAction,
            defaultKeyType: settings.resolvedEditDefaultKeyType
        )
    }

    private var hasActiveFilter: Bool {
        screenTimeService.hasActiveCustomDomainFilter()
    }

    private var isCustomDomainsToggleDisabled: Bool {
        settings.editProtectionMode == .unblockAll && hasActiveFilter
    }

    private var customDomainsBinding: Binding<Bool> {
        Binding(
            get: { settings.enableCustomDomains },
            set: { enabled in
                if enabled {
                    settings.enableCustomDomains = true
                    return
                }
                if settings.editProtectionMode == .requireKey,
                    editSessionService.isEditingBlocked(
                        mode: .requireKey,
                        keys: keys,
                        activeShieldCount: screenTimeService.activeShieldCount()
                    )
                {
                    customDomainsAuthAction = .weaken { proof in
                        guard proof.coversAllApps else { return }
                        settings.enableCustomDomains = false
                    }
                } else {
                    settings.enableCustomDomains = false
                }
            }
        )
    }

    private var websitesSection: some View {
        Section {
            Toggle(
                "Enable Custom Websites",
                isOn: customDomainsBinding
            )
            .disabled(isCustomDomainsToggleDisabled)
        } header: {
            Text("Websites")
        } footer: {
            if isCustomDomainsToggleDisabled {
                Text("Unblock all apps to turn this off.")
            }
        }
    }

    private var unblockingSection: some View {
        Section {
            NavigationLink {
                UnblockDurationsView(settings: settings)
            } label: {
                CountRow(title: "Unblock Durations", count: settings.unblockDurations.count)
            }
            .accessibilityIdentifier("settings.unblockDurationsLink")

            Picker(
                "Default Duration",
                selection: Binding(
                    get: { settings.defaultDuration },
                    set: { settings.defaultDuration = $0 }
                )
            ) {
                Text("None").tag(TimedUnblockDuration?.none)
                ForEach(settings.unblockDurations) { duration in
                    Text(duration.label).tag(TimedUnblockDuration?.some(duration))
                }
            }
            .adaptivePickerStyle()

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
            .adaptivePickerStyle()

            if availableKeyTypes.contains(.location) {
                BackgroundLocationRow()
            }

            Toggle(
                "Live Activity",
                isOn: Bindable(settings).showTimedUnblockLiveActivity
            )
        } header: {
            Text("Unblocking")
        }
    }

    private var blockingSection: some View {
        Section {
            UsageSummaryView()

            NavigationLink {
                EditProtectionView(settings: settings)
            } label: {
                LabeledContent("Edit Protection", value: settings.editProtectionMode.shortLabel)
            }
            .accessibilityIdentifier("settings.editProtectionLink")

            AdultContentToggleView(defaultKeyType: settings.defaultKeyType)

            Toggle(
                "Prevent App Deletion on Block All",
                isOn: Bindable(settings).blockAllPreventsAppDelete
            )

            Toggle(
                "Skip Block Without Key Confirmation",
                isOn: Bindable(settings).skipBlockWithoutKeyConfirmation
            )

            HideBlockedAppsToggleView()
        } header: {
            Text("Blocking")
        }
    }

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
            .adaptivePickerStyle()

            Toggle(
                "Hide Donate Button",
                isOn: Bindable(settings).hideDonateButton
            )
        } header: {
            Text("Appearance")
        }
    }

    private var aboutSection: some View {
        Section {
            Link(destination: Self.writeReviewURL) {
                Label("Rate Normal", systemImage: "star.fill")
            }
            NavigationLink {
                ContactUsView()
            } label: {
                Label("Contact Us", systemImage: "envelope")
            }
        }
    }
}
