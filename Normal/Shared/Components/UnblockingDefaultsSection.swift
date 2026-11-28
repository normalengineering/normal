import SwiftUI

struct UnblockingDefaultsSection: View {
    @Binding var durationOverride: DefaultOverride<TimedUnblockDuration>
    @Binding var keyOverride: DefaultOverride<KeyType>

    let durations: [TimedUnblockDuration]
    let availableKeyTypes: [KeyType]
    let appDefaultDurationLabel: String
    let appDefaultKeyLabel: String
    let durationAccessibilityID: String
    let keyAccessibilityID: String
    var footer: LocalizedStringKey?

    private var durationSelection: Binding<DefaultOverride<TimedUnblockDuration>> {
        Binding(
            get: {
                if case .value(let duration) = durationOverride, !durations.contains(duration) {
                    return .none
                }
                return durationOverride
            },
            set: { durationOverride = $0 }
        )
    }

    private var keySelection: Binding<DefaultOverride<KeyType>> {
        Binding(
            get: {
                if case .value(let keyType) = keyOverride, !availableKeyTypes.contains(keyType) {
                    return .none
                }
                return keyOverride
            },
            set: { keyOverride = $0 }
        )
    }

    var body: some View {
        Section {
            Group {
                if #available(iOS 18.0, *) {
                    Picker("Default Duration", selection: durationSelection) {
                        durationOptions(appDefault: String(localized: "App Default (\(appDefaultDurationLabel))"))
                    } currentValueLabel: {
                        Text(rowLabel(for: durationSelection.wrappedValue) { $0.label })
                    }
                } else {
                    Picker("Default Duration", selection: durationSelection) {
                        durationOptions(appDefault: String(localized: "App Default"))
                    }
                }
            }
            .adaptivePickerStyle()
            .accessibilityIdentifier(durationAccessibilityID)

            Group {
                if #available(iOS 18.0, *) {
                    Picker("Default Key", selection: keySelection) {
                        keyOptions(appDefault: String(localized: "App Default (\(appDefaultKeyLabel))"))
                    } currentValueLabel: {
                        Text(rowLabel(for: keySelection.wrappedValue) { $0.label })
                    }
                } else {
                    Picker("Default Key", selection: keySelection) {
                        keyOptions(appDefault: String(localized: "App Default"))
                    }
                }
            }
            .adaptivePickerStyle()
            .accessibilityIdentifier(keyAccessibilityID)
        } header: {
            Text("Unblocking")
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }

    @ViewBuilder
    private func durationOptions(appDefault: String) -> some View {
        Text(appDefault).tag(DefaultOverride<TimedUnblockDuration>.appDefault)
        Text("None").tag(DefaultOverride<TimedUnblockDuration>.none)
        ForEach(durations) { duration in
            Text(duration.label).tag(DefaultOverride.value(duration))
        }
    }

    @ViewBuilder
    private func keyOptions(appDefault: String) -> some View {
        Text(appDefault).tag(DefaultOverride<KeyType>.appDefault)
        Text("None").tag(DefaultOverride<KeyType>.none)
        ForEach(availableKeyTypes) { type in
            Label(type.label, systemImage: type.icon).tag(DefaultOverride.value(type))
        }
    }

    private func rowLabel<Value>(for choice: DefaultOverride<Value>, value: (Value) -> String) -> String {
        switch choice {
        case .appDefault: String(localized: "App Default")
        case .none: String(localized: "None")
        case .value(let chosen): value(chosen)
        }
    }
}
