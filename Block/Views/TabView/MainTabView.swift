import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Groups", systemImage: "app.shadow") {
                GroupsView()
            }
            Tab("App Select", systemImage: "app.dashed") {
                AppSelectView()
            }
            Tab("Keys", systemImage: "key.viewfinder") {
                KeysView()
            }
        }
    }
}
