import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
            }

            Tab("Groups", systemImage: "app.shadow", value: AppTab.groups) {
                GroupsView()
            }

            Tab("Schedules", systemImage: "calendar.badge.clock", value: AppTab.schedules) {
                SchedulesView()
            }

            Tab("App Select", systemImage: "app.dashed", value: AppTab.appSelect) {
                AppSelectView()
            }

            Tab("Keys", systemImage: "key.viewfinder", value: AppTab.keys) {
                KeysView()
            }
        }
    }
}
