import SwiftData
import SwiftUI

struct EditProtectionView: View {
    @Environment(ScreenTimeService.self) private var screenTimeService
    @Environment(EditSessionService.self) private var editSessionService
    @Query private var keys: [Key]

    let settings: Settings

    @State private var authAction: ProtectedAction?

    private var globalKeyTypes: [KeyType] {
        let globalKeys = Key.scoped(keys, toGroup: nil)
        return KeyType.allCases.filter { type in globalKeys.contains { $0.type == type } }
    }

    private var appDefaultDurationLabel: String {
        settings.defaultDuration?.label ?? String(localized: "None")
    }

    private var appDefaultKeyLabel: String {
        guard let keyType = settings.defaultKeyType, globalKeyTypes.contains(keyType) else {
            return String(localized: "None")
        }
        return keyType.label
    }

    var body: some View {
        Form {
            modeSection

            if settings.editProtectionMode == .requireKey {
                UnblockingDefaultsSection(
                    durationOverride: Bindable(settings).editDurationOverride,
                    keyOverride: Bindable(settings).editKeyOverride,
                    durations: settings.unblockDurations,
                    availableKeyTypes: globalKeyTypes,
                    appDefaultDurationLabel: appDefaultDurationLabel,
                    appDefaultKeyLabel: appDefaultKeyLabel,
                    durationAccessibilityID: "editProtection.defaultDuration",
                    keyAccessibilityID: "editProtection.defaultKey",
                    footer: "Choose a default key or duration when unblocking editing, or inherit your app defaults."
                )
            }
        }
        .navigationTitle("Edit Protection")
        .navigationBarTitleDisplayMode(.inline)
        .keySelect(
            action: $authAction,
            defaultKeyType: settings.resolvedEditDefaultKeyType
        )
    }

    private var modeSection: some View {
        Section {
            ForEach(EditProtectionMode.allCases) { mode in
                modeRow(mode)
            }
        } header: {
            Text("Allow Editing")
        } footer: {
            Text(settings.editProtectionMode.footer)
        }
    }

    private func modeRow(_ mode: EditProtectionMode) -> some View {
        let isSelected = settings.editProtectionMode == mode
        return Button {
            selectMode(mode)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(mode.label)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("settings.editProtection.\(mode.rawValue)")
    }

    private func selectMode(_ mode: EditProtectionMode) {
        let current = settings.editProtectionMode
        guard mode != current else { return }

        if editSessionService.requiresKeyToChangeMode(
            from: current,
            to: mode,
            keys: keys,
            activeShieldCount: screenTimeService.activeShieldCount()
        ) {
            authAction = .weaken { proof in
                guard proof.coversAllApps else { return }
                applyMode(mode)
            }
        } else {
            applyMode(mode)
        }
    }

    private func applyMode(_ mode: EditProtectionMode) {
        withAnimation {
            settings.editProtectionMode = mode
        }
        editSessionService.block()
    }
}
