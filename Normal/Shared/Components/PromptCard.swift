import SwiftUI

struct PromptCard<Content: View, Actions: View>: View {
    var cornerRadius: CGFloat = DS.Radius.xl
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: DS.Spacing.xxl) {
                Spacer()
                card
                Spacer()
            }
            ScrollView {
                card.padding(.vertical, DS.Spacing.xxl)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            content
            actions
        }
        .padding(DS.Spacing.xxl)
        .glassCardBackground(cornerRadius: cornerRadius)
        .padding(.horizontal, DS.Spacing.xxl)
    }
}
