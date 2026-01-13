import SwiftUI

struct MessageView: View {
    let message: String
    let color: Color

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.tertiary, lineWidth: 1)
            )
    }
}
