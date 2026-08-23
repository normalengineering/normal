import SwiftUI

/// One limit as it appears in the Usage list: what it covers, how long it
/// allows, and where it stands today.
struct UsageLimitRow: View {
    let limit: UsageLimit
    let state: UsageLimitState

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                SelectionIconsView(tokens: limit.selection.allTokens, limit: 5)
                Text(verbatim: limit.selection.selectedTokenCounts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(
                    title: LocalizedStringKey(state.shortLabel),
                    systemImage: state.icon,
                    tint: state.color
                )
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(DurationFormat.compact(minutes: limit.minutesPerDay))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
