import SwiftUI

struct CardView<Content: View>: View {
    let primaryText: String
    let secondaryText: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(primaryText)
                .font(.headline)
            HStack {
                content
                Spacer()
                Text(secondaryText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}
