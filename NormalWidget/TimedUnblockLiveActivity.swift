import ActivityKit
import SwiftUI
import WidgetKit

struct TimedUnblockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimedUnblockActivityAttributes.self) { context in
            lockScreen(context)
                .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ringWithIcon(context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text("Re-blocks when the timer ends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                ringWithIcon(context)
            } compactTrailing: {
                timerText(context)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 52, alignment: .trailing)
            } minimal: {
                ringWithIcon(context)
            }
            .keylineTint(.orange)
        }
    }

    private func lockScreen(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("Unblocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            timerText(context)
                .font(.title2.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .padding()
    }

    private func timerText(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        Text(timerInterval: range(context), countsDown: true)
            .multilineTextAlignment(.trailing)
    }

    private func ringWithIcon(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> some View {
        ProgressView(timerInterval: range(context), countsDown: true) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.circular)
        .tint(.orange)
        .frame(width: 24, height: 24)
        .overlay {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.orange)
        }
    }

    private func range(
        _ context: ActivityViewContext<TimedUnblockActivityAttributes>
    ) -> ClosedRange<Date> {
        context.attributes.startDate ... context.state.endDate
    }
}
