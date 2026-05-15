import SwiftUI

struct KeySelectView: View {
    let availableKeyTypes: [KeyType]
    let allowBypass: Bool
    let onSelect: (KeyType) -> Void
    let onBypass: () -> Void

    @State private var showBypassWarning = false

    var body: some View {
        List {
            Section {
                ForEach(availableKeyTypes) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        KeySelectRow(type: type)
                    }
                }
            }

            if allowBypass {
                Section {
                    Button {
                        showBypassWarning = true
                    } label: {
                        Text("Block without key")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .navigationTitle("Choose Key")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you sure?", isPresented: $showBypassWarning) {
            Button("Block without key", role: .destructive, action: onBypass)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to scan a key to unblock later. Make sure you have a valid key or you may be permanently locked out.")
        }
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
