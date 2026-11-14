import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab

    private static let tabs: [(tab: AppTab, icon: String)] = [
        (.home, "house"),
        (.groups, AppIcons.groups),
        (.schedules, "calendar.badge.clock"),
        (.appSelect, "app.dashed"),
        (.keys, "key.viewfinder"),
    ]

    var body: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selectedTab) {
                Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
                Tab("Groups", systemImage: AppIcons.groups, value: AppTab.groups) { GroupsView() }
                Tab("Schedules", systemImage: "calendar.badge.clock", value: AppTab.schedules) { SchedulesView() }
                Tab("App Select", systemImage: "app.dashed", value: AppTab.appSelect) { AppSelectView() }
                Tab("Keys", systemImage: "key.viewfinder", value: AppTab.keys) { KeysView() }
            }
        } else {
            TabView(selection: $selectedTab) {
                HomeView().tabItem { Label("Home", systemImage: "house") }.tag(AppTab.home)
                GroupsView().tabItem { Label("Groups", systemImage: AppIcons.groups) }.tag(AppTab.groups)
                SchedulesView().tabItem { Label("Schedules", systemImage: "calendar.badge.clock") }.tag(AppTab.schedules)
                AppSelectView().tabItem { Label("App Select", systemImage: "app.dashed") }.tag(AppTab.appSelect)
                KeysView().tabItem { Label("Keys", systemImage: "key.viewfinder") }.tag(AppTab.keys)
            }
        }
    }
}
