import SwiftUI

struct UsageLimitRow: View {
    let limit: UsageLimit
    let state: UsageLimitState
    let now: Date

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    SelectionIconsView(tokens: limit.selection.allTokens, limit: 5)
                }
                Text(verbatim: limit.selection.selectedTokenCounts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StatusBadge(title: state.label, systemImage: state.icon, tint: state.color)
                if case let .grace(until) = limit.lockState(now: now) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "pencil")
                        Text("\(UsageLockDeadline.countdown(to: until, now: now)) left to adjust")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
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
