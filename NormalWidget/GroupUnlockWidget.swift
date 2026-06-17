import SwiftUI
import WidgetKit

struct GroupEntry: TimelineEntry {
    let date: Date
    let groupID: UUID?
    let groupName: String?
    let isUnblocked: Bool
    let countdownEnd: Date?
    let durationSeconds: Int?
    let keyRawValue: String?

    static let placeholder = GroupEntry(
        date: Date(),
        groupID: nil,
        groupName: "Social Media",
        isUnblocked: false,
        countdownEnd: nil,
        durationSeconds: nil,
        keyRawValue: nil
    )

    var isConfigured: Bool { groupID != nil }

    var actionURL: URL? {
        guard let groupID else { return nil }
        return isUnblocked
            ? WidgetDeepLink.blockURL(groupID: groupID)
            : WidgetDeepLink.unlockURL(
                groupID: groupID,
                durationSeconds: durationSeconds,
                keyTypeRawValue: keyRawValue
            )
    }
}

struct GroupUnlockProvider: AppIntentTimelineProvider {
    private let store = WidgetSharedStore()

    func placeholder(in _: Context) -> GroupEntry { .placeholder }

    func snapshot(for configuration: SelectGroupIntent, in _: Context) async -> GroupEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectGroupIntent, in _: Context) async -> Timeline<GroupEntry> {
        let entry = entry(for: configuration)
        let policy: TimelineReloadPolicy = entry.countdownEnd.map { .after($0) } ?? .never
        return Timeline(entries: [entry], policy: policy)
    }

    private func entry(for configuration: SelectGroupIntent) -> GroupEntry {
        guard let group = configuration.group else {
            return GroupEntry(
                date: Date(),
                groupID: nil,
                groupName: nil,
                isUnblocked: false,
                countdownEnd: nil,
                durationSeconds: nil,
                keyRawValue: nil
            )
        }
        let now = Date()
        let state = store.groupState(forGroupId: group.id, now: now)
        return GroupEntry(
            date: now,
            groupID: group.id,
            groupName: store.group(id: group.id)?.name ?? group.name,
            isUnblocked: state.isUnblocked,
            countdownEnd: state.countdownEnd,
            durationSeconds: configuration.duration?.rawValue,
            keyRawValue: configuration.keyType?.id
        )
    }
}

struct GroupUnlockWidget: Widget {
    static let kind = "GroupUnlockWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectGroupIntent.self,
            provider: GroupUnlockProvider()
        ) { entry in
            GroupUnlockWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(entry.actionURL)
        }
        .configurationDisplayName("Quick Unlock")
        .description("Unlock a group straight from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
