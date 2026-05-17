import SwiftUI

struct CardActionButton: View {
    let title: String
    let systemImage: String
    let prominent: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: systemImage)
                Text(title)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .tint(tint)
        .modifier(StyleModifier(prominent: prominent))
    }
}

private struct StyleModifier: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}
