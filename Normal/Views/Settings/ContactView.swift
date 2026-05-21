import SwiftUI

struct ContactView: View {
    private static let contactEmail = "info@normalengineering.org"
    private static let contactURL = URL(string: "mailto:info@normalengineering.org")!

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("We'd love to hear from you.")
                        .font(.headline)
                    Text("If you have any issues, feedback or praise, please don't hesitate to contact us.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Spacing.xs)
            }

            Section {
                Link(destination: Self.contactURL) {
                    Label(Self.contactEmail, systemImage: "envelope.fill")
                }
            }
        }
    }
}
