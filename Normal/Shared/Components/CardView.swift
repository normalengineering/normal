import SwiftUI

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding()
        .contentShape(Rectangle())
        .glassEffect(in: .rect(cornerRadius: 16.0))
    }
}
