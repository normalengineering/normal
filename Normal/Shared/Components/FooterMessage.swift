import SwiftUI

struct FooterMessage: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
    }
}

enum BlockedMessage {
    static let groups: LocalizedStringKey = "Unblock all apps to add or edit groups."
    static let schedules: LocalizedStringKey = "Unblock all apps to add or edit schedules."
    static let keys: LocalizedStringKey = "Unblock all apps to add or delete keys."
    static let customDomains: LocalizedStringKey = "Unblock all apps to edit custom domains."
}
