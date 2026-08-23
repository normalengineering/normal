import SwiftUI

struct KeySelectView: View {
    let availableKeyTypes: [KeyType]
    let allowBypass: Bool
    @Binding var skipBypassConfirmation: Bool
    let onSelect: (KeyType) -> Void
    let onBypass: () -> Void

    @State private var showBypassWarning = false
    @State private var bypassConfirmed = false

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
                    Button {
                        if skipBypassConfirmation {
                            onBypass()
                        } else {
                            showBypassWarning = true
                        }
                    } label: {
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
        .sheet(isPresented: $showBypassWarning, onDismiss: runConfirmedBypass) {
            BypassConfirmSheet(
                onConfirm: { skipFuture in
                    if skipFuture { skipBypassConfirmation = true }
                    bypassConfirmed = true
                    showBypassWarning = false
                },
                onCancel: { showBypassWarning = false }
            )
        }
    }

    private func runConfirmedBypass() {
        guard bypassConfirmed else { return }
        bypassConfirmed = false
        onBypass()
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
