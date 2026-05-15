import SwiftUI

struct NumberedRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text("\(number).")
                .foregroundStyle(.secondary)
            Text(text)
        }
    }
}
