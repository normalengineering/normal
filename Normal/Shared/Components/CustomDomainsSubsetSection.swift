import SwiftUI

struct CustomDomainsSubsetSection: View {
    let available: [String]
    @Binding var selected: [String]

    var body: some View {
        Section {
            if available.isEmpty {
                Text("No custom domains yet. Add them in App Select.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(available, id: \.self) { domain in
                    row(for: domain)
                }
            }
        } header: {
            Text("Custom Domains")
        }
    }

    private func row(for domain: String) -> some View {
        let isOn = selected.contains(domain)
        return Button {
            toggle(domain)
        } label: {
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
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityIdentifier("customDomains.row.\(domain)")
    }

    private func toggle(_ domain: String) {
        if let index = selected.firstIndex(of: domain) {
            selected.remove(at: index)
        } else {
            selected.append(domain)
        }
    }
}
