import SwiftUI

struct PromptCard<Content: View, Actions: View>: View {
    var cornerRadius: CGFloat = DS.Radius.xl
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                content
                actions
            }
            .padding(DS.Spacing.xxl)
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
            .padding(.horizontal, DS.Spacing.xxl)
            Spacer()
        }
    }
}
