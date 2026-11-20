import SwiftUI

struct UsageLimitRow: View {
    let limit: UsageLimit
    let state: UsageLimitState
    let now: Date

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                SelectionIconRow(tokens: limit.selection.allTokens, maxCount: 5)
                Text(verbatim: limit.selection.selectedTokenCounts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(title: state.label, systemImage: state.icon, tint: state.color)
                if case .grace(let until) = limit.lockState(now: now) {
                    UsageGraceCountdown(until: until, now: now)
                        .accessibilityIdentifier("usage.graceCountdown")
                }
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(DurationFormat.compact(minutes: limit.minutesPerDay))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(DurationFormat.spelled(minutes: limit.minutesPerDay))
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}
