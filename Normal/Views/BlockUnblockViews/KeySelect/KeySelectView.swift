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
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.label)
                                    .font(.body)
                                Text(type.scanPrompt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: type.icon)
                                .font(.title2)
                                .frame(width: 32)
                        }
                        .padding(.vertical, 4)
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
            Button("Block without key", role: .destructive) { onBypass() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to scan a key to unblock later. Make sure you have a valid key or you may be permanently locked out.")
        }
    }
}
