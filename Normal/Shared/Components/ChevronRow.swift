import SwiftUI

struct ChevronRow<Trailing: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            trailing
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

extension ChevronRow where Trailing == EmptyView {
    init(title: LocalizedStringKey) {
        self.init(title: title) { EmptyView() }
    }
}

struct CountChevronRow: View {
    let title: LocalizedStringKey
    let count: Int

    var body: some View {
        ChevronRow(title: title) {
            if count > 0 {
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
