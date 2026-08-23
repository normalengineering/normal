import SwiftUI

struct PrimaryActionButton: View {
    let title: LocalizedStringKey
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xs)
        }
        .buttonStyle(.borderedProminent)
    }
}

struct SecondaryTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .foregroundStyle(.secondary)
    }
}
