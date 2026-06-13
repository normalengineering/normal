import SwiftUI
import WidgetKit

struct GroupUnlockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupEntry

    private var isUnblocked: Bool { entry.isUnblocked }

    var body: some View {
        if entry.isConfigured {
            switch family {
            case .systemMedium: mediumBody
            default: smallBody
            }
        } else {
            unconfiguredBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusIcon
            Spacer(minLength: 0)
            Text(entry.groupName ?? "Group")
                .font(.headline)
                .lineLimit(2)
            statusLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mediumBody: some View {
        HStack(spacing: 16) {
            statusIcon
                .frame(width: 56, height: 56)
                .background(iconTint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.groupName ?? "Group")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                statusLine
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unconfiguredBody: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.open.rotation")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Hold and tap 'Edit Widget' to configure")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusIcon: some View {
        Image(systemName: isUnblocked ? "lock.open.fill" : "lock.fill")
            .font(family == .systemMedium ? .title2 : .title3)
            .foregroundStyle(iconTint)
            .symbolRenderingMode(.hierarchical)
    }

    @ViewBuilder
    private var statusLine: some View {
        if isUnblocked {
            VStack(alignment: .leading, spacing: 2) {
                if let end = entry.countdownEnd {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(timerInterval: entry.date ... end, countsDown: true)
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                }
                Text("Tap to block")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Tap to unlock")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var iconTint: Color {
        isUnblocked ? .orange : .blue
    }
}
