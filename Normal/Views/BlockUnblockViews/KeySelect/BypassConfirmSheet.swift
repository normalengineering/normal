import SwiftUI

/// Confirmation for blocking without a key. A plain alert can't host the
/// "Don't show this again" checkmark, so this stands in for one.
struct BypassConfirmSheet: View {
    let onConfirm: (_ skipFutureConfirmations: Bool) -> Void
    let onCancel: () -> Void

    @State private var dontShowAgain = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(spacing: DS.Spacing.sm) {
                    Text("Are you sure?")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)

                    Text("You'll need to scan a key to unblock later. Make sure you have a valid key or you may be permanently locked out.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                dontShowAgainRow

                VStack(spacing: DS.Spacing.sm) {
                    PrimaryActionButton(title: "Block without key", role: .destructive) {
                        onConfirm(dontShowAgain)
                    }
                    .accessibilityIdentifier("keySelect.confirmBlockWithoutKey")

                    SecondaryTextButton(title: "Cancel", action: onCancel)
                        .accessibilityIdentifier("keySelect.cancelBlockWithoutKey")
                }
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.height(400), .large])
        .presentationDragIndicator(.visible)
    }

    private var dontShowAgainRow: some View {
        Button {
            dontShowAgain.toggle()
        } label: {
            Label {
                Text("Don't show this again")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(dontShowAgain ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle("Don't show this again", isOn: $dontShowAgain)
                .accessibilityIdentifier("keySelect.dontShowAgain")
        }
    }
}
