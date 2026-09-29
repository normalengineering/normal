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
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
