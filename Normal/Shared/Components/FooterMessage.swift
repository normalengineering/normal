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
