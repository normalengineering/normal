import SwiftUI

struct MainTabView : View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house"){
                HomeView()
            }
            Tab("App Groups", systemImage: "app.shadow"){
                AppSelectView()
            }
        }
    }
}
