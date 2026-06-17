import SwiftUI

struct ContactUsView: View {
    private static let email = "info@normalengineering.org"

    var body: some View {
        List {
            Section {
                Text("Since Normal collects no data, contacting us is the only way to share suggestions, give feedback, or report a bug. We appreciate your feedback!")
                    .font(.callout)
            }

            Section("Email") {
                if let url = URL(string: "mailto:\(Self.email)") {
                    Link(destination: url) {
                        Label(Self.email, systemImage: "envelope.fill")
                    }
                    .accessibilityIdentifier("contact.emailLink")
                }
            }
        }
        .navigationTitle("Contact Us")
        .navigationBarTitleDisplayMode(.inline)
    }
}
