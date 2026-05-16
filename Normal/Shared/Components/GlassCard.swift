import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = DS.Radius.lg
    var spacing: CGFloat = DS.Spacing.lg
    var alignment: HorizontalAlignment = .leading
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .glassCardBackground(cornerRadius: cornerRadius)
    }
}
