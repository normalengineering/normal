import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TimedUnblockLiveActivity: Widget {
    private let compactTimerWidth: CGFloat = 44

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimedUnblockActivityAttributes.self) { context in
            atEnd(context) { finished in
                HStack(spacing: 12) {
                    leadingInfo(context, finished: finished)
                    Spacer(minLength: 8)
                    trailingAccessory(context, finished: finished)
                }
                .padding(16)
            }
            .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    atEnd(context) { finished in
                        HStack(spacing: 12) {
                            leadingInfo(context, finished: finished)
                            Spacer(minLength: 8)
                            trailingAccessory(context, finished: finished)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                    }
                }
            } compactLeading: {
                leadingIcon(context)
            } compactTrailing: {
                atEnd(context) { finished in
                    if !finished {
                        timerText(context)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(width: compactTimerWidth, alignment: .trailing)
                    }
                }
            } minimal: {
                leadingIcon(context)
            }
            .keylineTint(.orange)
        }
    }

    private func leadingInfo(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>,
        finished: Bool
    ) -> some View {
        HStack(spacing: 10) {
            iconBadge(systemName: finished ? "lock.fill" : "lock.open.fill")
            infoText(context, finished: finished)
        }
    }

    private func infoText(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>,
        finished: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(context.attributes.title)
                .font(.headline)
                .lineLimit(1)
            Text(finished ? "Blocked" : "Unblocked")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func trailingAccessory(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>,
        finished: Bool
    ) -> some View {
        if finished {
            Button(intent: DismissUnblockActivityIntent(unblockID: context.attributes.unblockID)) {
                Text("Dismiss")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            timerText(context)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private func iconBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.orange)
            .frame(width: 36, height: 36)
            .background(.orange.opacity(0.15), in: Circle())
    }

    @ViewBuilder
    private func atEnd<V: View>(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>,
        @ViewBuilder _ content: @escaping (_ finished: Bool) -> V
    ) -> some View {
        TimelineView(.explicit([context.state.endDate])) { _ in
            content(isFinished(context))
        }
    }

    private func timerText(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        Text(timerInterval: range(context), countsDown: true)
            .multilineTextAlignment(.trailing)
    }

    @ViewBuilder
    private func leadingIcon(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        atEnd(context) { finished in
            if finished {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)
            } else {
                ringWithIcon(context)
            }
        }
    }

    private func ringWithIcon(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        ProgressView(timerInterval: range(context), countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
        }
        .progressViewStyle(.circular)
        .tint(.orange)
    }

    private func range(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> ClosedRange<Date> {
        context.attributes.startDate ... context.state.endDate
    }

    private func isFinished(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> Bool {
        context.isStale || Date() >= context.state.endDate
    }
}
