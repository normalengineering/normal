import AppIntents

struct NormalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BlockAllIntent(),
            phrases: [
                "Block all apps in \(.applicationName)",
                "Block everything in \(.applicationName)",
                "\(.applicationName) block all",
            ],
            shortTitle: "Block All",
            systemImageName: "lock.fill"
        )
        AppShortcut(
            intent: BlockGroupIntent(),
            phrases: [
                "Block \(\.$group) in \(.applicationName)",
                "\(.applicationName) block \(\.$group)",
                "Block a group in \(.applicationName)",
            ],
            shortTitle: "Block Group",
            systemImageName: "lock.square.stack.fill"
        )
        AppShortcut(
            intent: UnblockAllIntent(),
            phrases: [
                "Unblock all apps in \(.applicationName)",
                "Unblock everything in \(.applicationName)",
                "\(.applicationName) unblock all",
            ],
            shortTitle: "Unblock All",
            systemImageName: "lock.open.fill"
        )
        AppShortcut(
            intent: UnblockGroupIntent(),
            phrases: [
                "Unblock \(\.$group) in \(.applicationName)",
                "\(.applicationName) unblock \(\.$group)",
                "Unblock a group in \(.applicationName)",
            ],
            shortTitle: "Unblock Group",
            systemImageName: "lock.open"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
