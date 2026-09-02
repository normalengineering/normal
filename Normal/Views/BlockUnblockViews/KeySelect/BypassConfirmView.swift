import SwiftUI

struct BypassConfirmView: View {
    let onConfirm: (_ skipFutureConfirmations: Bool) -> Void

    @State private var dontShowAgain = false
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, options: .nonRepeating, value: hasAppeared)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text("Block Without Key?")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Text("You'll need a key to unblock later. Without one, you could be permanently locked out.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: DS.Spacing.md) {
                Button {
                    onConfirm(dontShowAgain)
                } label: {
                    Text("Block Without Key")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityIdentifier("keySelect.confirmBlockWithoutKey")

                Button {
                    dontShowAgain.toggle()
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: dontShowAgain ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(dontShowAgain ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            .font(.title3)
                            .contentTransition(.symbolEffect(.replace))

                        Text("Don't ask again")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("keySelect.dontShowAgain")
                .accessibilityAddTraits(dontShowAgain ? .isSelected : [])
            }
        }
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.top, DS.Spacing.xxxl)
        .padding(.bottom, DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hasAppeared = true }
        .sensoryFeedback(.warning, trigger: hasAppeared)
    }
}
