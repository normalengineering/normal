import SwiftUI

struct CustomDomainsEditor: View {
    @Binding var domains: [String]

    var otherItemCount: Int = 0
    var isEditable: Bool = true

    @State private var input = ""
    @State private var message: FieldMessage?
    @State private var messageVersion = 0

    private struct FieldMessage: Equatable {
        var text: String
        var isError: Bool
        static func error(_ text: String) -> Self { .init(text: text, isError: true) }
        static func warning(_ text: String) -> Self { .init(text: text, isError: false) }
    }

    var body: some View {
        Form {
            if isEditable { inputSection }
            if !domains.isEmpty { domainsSection }
        }
        .navigationTitle("Custom Domains")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(trigger: messageVersion) { _, _ in
            message == nil ? .impact(weight: .medium) : .warning
        }
        .task(id: messageVersion) {
            guard message != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            message = nil
        }
    }

    private var inputSection: some View {
        Section {
            HStack {
                TextField("example.com", text: $input)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("customDomains.field")
                Button("Add", action: add)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("customDomains.addButton")
            }
        } footer: {
            if let message {
                Text(message.text)
                    .foregroundStyle(message.isError ? Color.red : .secondary)
            }
        }
    }

    private var domainsSection: some View {
        Section {
            ForEach(domains, id: \.self) { domain in
                HStack {
                    Label(domain, systemImage: "globe")
                        .lineLimit(1)
                    if isEditable {
                        Spacer()
                        deleteButton(domain)
                    }
                }
            }
            .onDelete(perform: deleteAction)
        } footer: {
            if !isEditable {
                Text(BlockedMessage.customDomains)
            }
        }
    }

    private func deleteButton(_ domain: String) -> some View {
        Button(role: .destructive) {
            remove(domain)
        } label: {
            Image(systemName: "minus.circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete \(domain)")
        .accessibilityIdentifier("customDomains.delete.\(domain)")
    }

    private func show(_ newMessage: FieldMessage?) {
        message = newMessage
        messageVersion += 1
    }

    private func add() {
        switch CustomDomains.evaluateAdd(input, existing: domains, otherItemCount: otherItemCount) {
        case .invalid:
            show(.error("Enter a valid domain like example.com."))
        case let .duplicate(domain):
            show(.error("\(domain) already added"))
            input = ""
        case let .added(domain, overLimit):
            withAnimation(.snappy(duration: 0.2)) { domains.append(domain) }
            input = ""
            show(overLimit
                ? .warning("\(ScreenTimeLimits.maxBlockedItems)+ items can't be blocked at once and may cause issues")
                : nil)
        }
    }

    private func remove(_ domain: String) {
        domains.removeAll { $0 == domain }
        show(nil)
    }

    private var deleteAction: ((IndexSet) -> Void)? {
        guard isEditable else { return nil }
        return { offsets in
            domains.remove(atOffsets: offsets)
            show(nil)
        }
    }
}
