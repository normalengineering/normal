import SwiftUI

struct CustomDomainSubsetRow: View {
    let domain: String
    @Binding var selected: [String]
    var isEditable: Bool = true

    private var isOn: Bool { selected.contains(domain) }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.45))
                Label(domain, systemImage: "globe")
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEditable)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityIdentifier("customDomains.row.\(domain)")
    }

    private func toggle() {
        if let index = selected.firstIndex(of: domain) {
            selected.remove(at: index)
        } else {
            selected.append(domain)
        }
    }
}

struct CustomDomainsSubsetSection: View {
    let available: [String]
    @Binding var selected: [String]

    var body: some View {
        Section("Custom Domains") {
            if available.isEmpty {
                Text("No custom domains yet. Add them in App Select.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(available, id: \.self) { domain in
                    CustomDomainSubsetRow(domain: domain, selected: $selected)
                }
            }
        }
    }
}

struct CustomDomainsSubsetLink: View {
    let available: [String]
    @Binding var selected: [String]
    var isEditable: Bool = true

    private var effectiveCount: Int {
        CustomDomains.subset(selected, of: available).count
    }

    var body: some View {
        NavigationLink {
            CustomDomainsSubsetEditor(available: available, selected: $selected, isEditable: isEditable)
        } label: {
            CountRow(title: "Custom Domains", count: effectiveCount)
                .opacity(isEditable ? 1 : DS.Opacity.dim)
        }
        .accessibilityIdentifier("customDomains.subsetLink")
    }
}

struct CustomDomainsSubsetEditor: View {
    let available: [String]
    @Binding var selected: [String]
    var isEditable: Bool = true

    var body: some View {
        Form {
            Section {
                if available.isEmpty {
                    Text("No custom domains yet. Add them in App Select.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available, id: \.self) { domain in
                        CustomDomainSubsetRow(domain: domain, selected: $selected, isEditable: isEditable)
                    }
                }
            } footer: {
                if !isEditable {
                    Text(BlockedMessage.customDomains)
                }
            }
        }
        .navigationTitle("Custom Domains")
        .navigationBarTitleDisplayMode(.inline)
    }
}
