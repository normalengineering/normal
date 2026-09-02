import SwiftUI

struct KeySelectView: View {
    let availableKeyTypes: [KeyType]
    let allowBypass: Bool
    let onSelect: (KeyType) -> Void
    let onBypass: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(availableKeyTypes) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        KeySelectRow(type: type)
                    }
                    .accessibilityIdentifier("keySelect.row.\(type.rawValue)")
                }
            }

            if allowBypass {
                Section {
                    Button(action: onBypass) {
                        Text("Block without key")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("keySelect.blockWithoutKey")
                }
            }
        }
        .navigationTitle("Choose Key")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct KeySelectRow: View {
    let type: KeyType

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(type.label).font(.body)
                Text(type.scanPrompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: type.icon)
                .font(.title2)
                .frame(width: DS.Size.iconWell + 4)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
