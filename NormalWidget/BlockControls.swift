import AppIntents
import SwiftUI
import WidgetKit

struct BlockAllControl: ControlWidget {
    static let kind = "BlockAllControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: BlockAllIntent()) {
                Label("Block All", systemImage: "lock.fill")
                    .controlWidgetActionHint("Block")
            }
        }
        .displayName("Block All")
        .description("Blocks all the apps selected in Normal.")
    }
}

struct BlockGroupControl: ControlWidget {
    static let kind = "BlockGroupControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, intent: BlockGroupControlConfiguration.self) { configuration in
            ControlWidgetButton(action: BlockGroupIntent(group: configuration.group)) {
                Group {
                    if let group = configuration.group {
                        Label(group.name, systemImage: "lock.square.stack.fill")
                    } else {
                        Label("Block Group", systemImage: "lock.square.stack.fill")
                    }
                }
                .controlWidgetActionHint("Block")
            }
        }
        .displayName("Block Group")
        .description("Blocks one of your Normal groups.")
        .promptsForUserConfiguration()
    }
}

struct BlockGroupControlConfiguration: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Block Group"

    @Parameter(title: "Group")
    var group: GroupEntity?
}
