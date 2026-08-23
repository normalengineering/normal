import SwiftUI

struct MessageView: View {
    let text: Text
    let color: Color

    init(message: String, color: Color) {
        self.init(text: Text(message), color: color)
    }

    init(text: Text, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        text
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

extension View {
    func standaloneListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
    }
}
