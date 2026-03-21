import SwiftUI

struct ListView<T: Identifiable, Content: View>: View {
    let items: [T]
    @ViewBuilder let rowContent: (T) -> Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items, content: rowContent)
            }
            .padding(.horizontal, 16)
        }
    }
}
